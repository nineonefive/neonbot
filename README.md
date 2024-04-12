# neonbot

A Discord bot made for my Valorant premier team.

## Features

### Match Scheduling

Neonbot automatically schedules Valorant's Premier league events for the upcoming week in the Discord events tab.

![image](https://github.com/nineonefive/neonbot/assets/8103071/3ba71d0c-e8ef-4f44-927c-5605beaac65d)

### Match Reminders

Each event can record signups of your team members who have a designated signup role. 30 minutes before the start
of a game, if an event has enough (5) signups, the event will be started, alerting all interested members.

![image](https://github.com/nineonefive/neonbot/assets/8103071/088ea854-b56d-467f-82e7-264500ea1d64)

### Team Info

You can check the status of your Premier team with `/team`, which includes rank and Premier score.

![image](https://github.com/nineonefive/neonbot/assets/8103071/0175a200-977c-447b-af44-6bf4afd5922e)

### Schedule

You can view the upcoming Premier schedule with `/schedule`.

![image](https://github.com/nineonefive/neonbot/assets/8103071/55978759-7c0d-4b24-be23-d3c1088badd4)


## Inviting to your server

1. Use [this link](https://discord.com/oauth2/authorize?client_id=1225263921649160283) to invite the bot.

2. Next, add your premier team with `/config team <riot id>`.

3. Finally, use `/config edit` to adjust other preferences about where the bot will post messages.

### Permissions breakdown

The following permissions are required for Neonbot:
- **Add reactions**: The bot posts a ✅ on every signup alert so you know which team members have signed up in the events tab.
- **Create/manage events**: This is necessary to add Premier matches to the Discord events tab.
- **Use slash commands**: This is the primary way of interfacing with the bot and configuring your Discord server.
- **Send messages**: The bot sends a message when the weekly schedules have been updated.

The following permissions are optional and likely won't impact the bot at all:
- **Read messages**: This is just for some goofy automatic reactions in my Premier discord. It won't work in yours, and I don't collect your messages anyways.
- **Mention everyone**: Likely not necessary if you have a special team signup role.

## Running your own version

```bash
# Put the discord client token into a json file named api_keys.json
$ echo "{\"discord\": \"<TOKEN>\"}" > api_keys.json
# Start the bot
$ dart run
```
