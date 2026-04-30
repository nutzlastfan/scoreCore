from django.core.management.base import BaseCommand, CommandError
from django.db import connection


class Command(BaseCommand):
    help = "Recreates db-schema"

    def handle(self, *args, **options):
        if connection.vendor != "postgresql":
            raise CommandError("dropschema is only supported for PostgreSQL. Use Django migrations or SQL Server tools.")

        with connection.cursor() as cursor:
            cursor.execute("DROP SCHEMA public CASCADE;")
            cursor.execute("CREATE SCHEMA public;")
            print("DB cleared!")
