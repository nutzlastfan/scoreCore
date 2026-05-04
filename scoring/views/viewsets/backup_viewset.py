import os
from datetime import datetime

from django.core.management import call_command
from django.utils import timezone
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAdminUser

from scoring.helper import delete_file, get_path_backup
from scoring.linux import extract_date_from_filename
from scoring.models import Backup
from scoring.serializers import BackupSerializer
from scoring.views.viewsets.base_viewset import StandardResultsSetPagination
from server import settings
from server.views import RequestSuccess


class BackupViewSet(viewsets.ModelViewSet):
    pagination_class = StandardResultsSetPagination
    serializer_class = BackupSerializer
    queryset = Backup.objects.all().order_by("-id")
    permission_classes = [IsAdminUser]

    @action(detail=False, url_path="readin", methods=["POST"])
    def read_backups(self, request):
        _path = get_path_backup()
        _files = os.listdir(_path)
        for _f in _files:
            try:
                Backup.objects.get(name=_f)
            except Backup.DoesNotExist:
                backup = Backup.objects.create(name=_f)
                backup.date = extract_date_from_filename(_f)
                backup.save()
                #change_file_owner(os.path.join(_path, _f))

        return RequestSuccess()

    @action(detail=True, url_path="delete", methods=["POST"])
    def delete_backup(self, request, pk):
        backup = Backup.objects.get(pk=pk)
        delete_file(backup.get_file(), True)
        backup.delete()
        return self.list(request)

    @action(detail=False, url_path="deleteAll", methods=["POST"])
    def delete_all_backups(self, request):
        backups = Backup.objects.all()
        for backup in backups:
            delete_file(backup.get_file(), True)
            backup.delete()

        return self.list(request)

    @action(detail=False, url_path="reload", methods=["POST"])
    def reload_backups(self, request):
        call_command("readbackups")
        return self.list(request)

    @action(detail=False, url_path="create", methods=["POST"])
    def create_backup(self, request):
        if not settings.DBBACKUP_CONNECTORS:
            backup_name = f"scorecore-{timezone.localtime().strftime('%Y-%m-%d-%H%M%S')}.json"
            backup_path = os.path.join(get_path_backup(), backup_name)
            with open(backup_path, "w", encoding="utf-8") as backup_file:
                call_command(
                    "dumpdata",
                    "--natural-foreign",
                    "--natural-primary",
                    "--exclude",
                    "contenttypes",
                    "--exclude",
                    "auth.permission",
                    "--indent",
                    "2",
                    stdout=backup_file,
                )
            Backup.objects.get_or_create(
                name=backup_name,
                defaults={"date": timezone.make_aware(datetime.strptime(backup_name[10:-5], "%Y-%m-%d-%H%M%S"))},
            )
            return self.list(request)

        call_command("dbbackup")
        call_command("readbackups")
        return self.list(request)

    @action(detail=True, url_path="restore", methods=["POST"])
    def restore_backup(self, request, pk):
        if not settings.DBBACKUP_CONNECTORS:
            backup = Backup.objects.get(pk=pk)
            if not backup.name.endswith(".json"):
                return RequestSuccess({"warning": "Only JSON backups can be restored for this database engine."})
            call_command("loaddata", backup.get_file())
            call_command("readbackups")
            return self.list(request)

        backup = Backup.objects.get(pk=pk)
        call_command("dbrestore", f"--input-file={backup.name}", "--noinput")
        call_command("readbackups")
        return self.list(request)
