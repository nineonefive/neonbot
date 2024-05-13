# Update from github main branch
echo "Updating from github main branch"
git fetch && git reset --hard origin/main

# Generate deployment targets
echo "Building neonbot"
mkdir -p deploy
dart run nyxx_commands:compile -o neonbot.dart bin/neonbot.dart
mv neonbot.exe deploy/neonbot.exe
mv neonbot.dart deploy/neonbot.dart
cp api_keys.json deploy/api_keys.json

# Run neonbot in the deploy folder
echo "Running in deploy folder"
cd deploy
./neonbot.exe --cloudflare
