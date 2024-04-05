mkdir -p deploy

dart run nyxx_commands:compile -o neonbot.dart bin/neonbot.dart
mv neonbot.exe deploy/neonbot.exe
mv neonbot.dart deploy/neonbot.dart
cp api_keys.json deploy/api_keys.json
