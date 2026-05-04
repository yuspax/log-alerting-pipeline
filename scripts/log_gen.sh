LEVELS=("ERROR" "CRITICAL" "WARNING" "INFO")
MESSAGES=(
  "Database connection failed"
  "Service timeout after 30s"
  "Disk usage above 90 percent"
  "Memory allocation failed"
  "API rate limit exceeded"
  "Unauthorized access attempt"
  "Connection refused on port 5432"
)

LOG_FILE="/var/log/app/application.log"

echo "Starting log generator... Press Ctrl+C to stop"

while true; do
  LEVEL=${LEVELS[$RANDOM % ${#LEVELS[@]}]}
  MESSAGE=${MESSAGES[$RANDOM % ${#MESSAGES[@]}]}
  echo "$(date '+%Y-%m-%d %H:%M:%S') $LEVEL: $MESSAGE" >> "$LOG_FILE"
  echo "Written: $LEVEL: $MESSAGE"
  sleep 60
done