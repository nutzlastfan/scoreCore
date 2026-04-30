from django.urls import re_path

from server import settings

ws_pattern = []

if settings.DOCKER_FEATURE_ENABLED:
    from scoring.consumer import DockerConsumer
    ws_pattern.append(re_path(r'^ws/docker/status', DockerConsumer.as_asgi()))
