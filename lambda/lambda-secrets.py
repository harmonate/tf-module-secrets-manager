import boto3
import os
import json
import secrets  # for generating a secure random password
import string  # for character sets

secretsmanager = boto3.client('secretsmanager')
cognito = boto3.client('cognito-idp')
rds = boto3.client('rds')

if os.getenv('USER_POOL_ID'):
    USER_POOL_ID = os.getenv('USER_POOL_ID')
    CREDENTIAL_TYPE = 'cognito'
elif os.getenv('RDS_INSTANCE_ARN'):
    RDS_INSTANCE_ARN = os.getenv('RDS_INSTANCE_ARN')
    CREDENTIAL_TYPE = 'database'
elif os.getenv('ONLY_ROTATE_SECRET'):
    CREDENTIAL_TYPE = 'rotate_only'
else:
    raise ValueError("USER_POOL_ID, RDS_INSTANCE_ARN, or ONLY_ROTATE_SECRET environment variable is required")

def lambda_handler(event, context):
    secret_id = event['SecretId']
    token = event['ClientRequestToken']
    step = event['Step']

    if step == "createSecret":
        create_secret(secret_id, token)
    elif step == "setSecret":
        set_secret(secret_id, token)
    elif step == "testSecret":
        test_secret(secret_id, token)
    elif step == "finishSecret":
        finish_secret(secret_id, token)
    else:
        raise ValueError("Invalid step parameter")

def create_secret(secret_id, token):
    # Check if the current secret version is already created
    try:
        secretsmanager.get_secret_value(
            SecretId=secret_id,
            VersionId=token,
            VersionStage="AWSPENDING"
        )
    except secretsmanager.exceptions.ResourceNotFoundException:
        # Generate a new random password
        new_password = generate_random_password()
        # Get the current secret to keep the username
        current_secret = secretsmanager.get_secret_value(SecretId=secret_id)
        current_secret_value = json.loads(current_secret['SecretString'])
        # Create the new secret value
        new_secret_value = {
            'username': current_secret_value['username'],
            'password': new_password
        }
        # Store the new secret
        secretsmanager.put_secret_value(
            SecretId=secret_id,
            ClientRequestToken=token,
            SecretString=json.dumps(new_secret_value),
            VersionStages=['AWSPENDING']
        )

def set_secret(secret_id, token):
    # Get the new secret value
    secret = secretsmanager.get_secret_value(
        SecretId=secret_id,
        VersionId=token,
        VersionStage="AWSPENDING"
    )
    new_secret_value = json.loads(secret['SecretString'])

    if CREDENTIAL_TYPE == 'cognito':
        # Update the Cognito user with the new password
        try:
            cognito.admin_set_user_password(
                UserPoolId=USER_POOL_ID,
                Username=new_secret_value['username'],
                Password=new_secret_value['password'],
                Permanent=True
            )
        except cognito.exceptions.UserNotFoundException:
            raise ValueError(f"User {new_secret_value['username']} not found in the User Pool {USER_POOL_ID}")
    elif CREDENTIAL_TYPE == 'database':
        # Update the database user with the new password
        try:
            update_database_password(new_secret_value['username'], new_secret_value['password'])
        except Exception as e:
            raise ValueError(f"Failed to update database password: {str(e)}")
    elif CREDENTIAL_TYPE == 'rotate_only':
        # No action needed for rotating the secret only
        pass

def test_secret(secret_id, token):
    # No action needed for test_secret in this scenario
    pass

def finish_secret(secret_id, token):
    # Finalize the rotation process
    metadata = secretsmanager.describe_secret(SecretId=secret_id)
    current_version = None
    for version in metadata['VersionIdsToStages']:
        if "AWSCURRENT" in metadata['VersionIdsToStages'][version]:
            current_version = version
            break

    # Mark the new secret version as current
    secretsmanager.update_secret_version_stage(
        SecretId=secret_id,
        VersionStage="AWSCURRENT",
        MoveToVersionId=token,
        RemoveFromVersionId=current_version
    )

def generate_random_password(length=12, special_characters="_%@#"):
    # Character sets
    all_characters = string.ascii_letters + string.digits + special_characters
    password = [
        secrets.choice(string.ascii_lowercase),
        secrets.choice(string.ascii_uppercase),
        secrets.choice(string.digits),
        secrets.choice(special_characters)
    ]

    # Fill the rest of the password length with random characters
    password += [secrets.choice(all_characters) for _ in range(length - len(password))]

    # Shuffle the list to avoid any patterns and convert to a string
    secrets.SystemRandom().shuffle(password)
    return ''.join(password)

def update_database_password(username, password):
    # Example function to update database password
    # Implement the logic to update the password for the database user
    response = rds.modify_db_instance(
        DBInstanceIdentifier=RDS_INSTANCE_ARN.split(':')[6],  # Extract the DB instance identifier from the ARN
        MasterUserPassword=password
    )
    return response
