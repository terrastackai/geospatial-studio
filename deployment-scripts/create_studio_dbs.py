# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import os
from urllib.parse import urlparse
import argparse


import dotenv
import pg8000.native


parser = argparse.ArgumentParser(description="Run create bucket with a specified .env file.")
parser.add_argument('--env-path', type=str, default=None,
                    help="Path to the .env file.")
args = parser.parse_args()

if args.env_path:
    env_file_path = os.path.abspath(args.env_path)
    dotenv.load_dotenv(dotenv_path=env_file_path)
else:
    dotenv.load_dotenv()


# Database connection parameters
# These can be set in the .env file or as environment variables
database = os.getenv("pg_original_db_name")
user = os.getenv("pg_username")
password = os.getenv("pg_password")
host = os.getenv("pg_uri")
original_port = os.getenv("pg_port")
port = os.getenv("pg_forwarded_port", original_port)

# Studio database names
studio_db_name = os.getenv("pg_studio_db_name", "gfmstudio")
auth_db_name = f"{studio_db_name}_auth"

# If DATABASE_URL is set, parse it to get the connection parameters
# This is useful for cloud databases where the URL is provided
# in the format: postgres://user:password@host:port/database
if db_url := os.getenv("DATABASE_URL"):
    parsed = urlparse(db_url)
    database = parsed.path.lstrip("/")
    user = parsed.username
    password = parsed.password
    host = parsed.hostname
    port = parsed.port

# Create a connection to the PostgreSQL database
con = pg8000.native.Connection(
    user=user,
    password=password,
    host=host,
    port=port,
    database=database
)


# Create a temporary table
try:
    if os.getenv("create_db_user", "false").lower() == "true":
        con.run(
            f"CREATE USER {os.getenv('pg_studio_user', user)} WITH ENCRYPTED PASSWORD '{os.getenv('pg_studio_password', password)}';"
        )
    con.run(f"CREATE DATABASE {studio_db_name};")
    con.run(
        f"GRANT ALL PRIVILEGES ON DATABASE {studio_db_name} TO {os.getenv('pg_username', user)};"
    )
except:
    print(f"Database {studio_db_name} already exists or could not be created")


try:
    con.run(f"CREATE DATABASE mlflow;")
    con.run(f"GRANT ALL PRIVILEGES ON DATABASE mlflow TO {os.getenv('pg_username', user)};")
except:
    print(f"Database mlflow already exists or could not be created")

try:
    con.run(f"CREATE DATABASE {auth_db_name};")
    con.run(
        f"GRANT ALL PRIVILEGES ON DATABASE {auth_db_name} TO {os.getenv('pg_username', user)};"
    )
except:
    # con.run(f"DROP DATABASE {auth_db_name};")
    print(f"Database {auth_db_name} already exists or could not be created")

try:
    con.run(f"CREATE DATABASE keycloak;")
    con.run(f"GRANT ALL PRIVILEGES ON DATABASE keycloak TO {os.getenv('pg_username', user)};")
except:
    print(f"Database keycloak already exists or could not be created")


con.close()

## TO DO - Add code to create tables - this will be done by the deployment scripts
## TO DO - populate tables with initial data
