param(
    [ValidateSet("up", "down", "logs", "restart")]
    [string]$Action = "up"
)

$ErrorActionPreference = "Stop"
$composeFile = "docker-compose.server.yml"

switch ($Action) {
    "up" {
        docker compose -f $composeFile up -d
    }
    "down" {
        docker compose -f $composeFile down
    }
    "logs" {
        docker compose -f $composeFile logs -f --tail 200
    }
    "restart" {
        docker compose -f $composeFile down
        docker compose -f $composeFile up -d
    }
}
