#!/bin/bash
# shellcheck source=scripts/helper_functions.sh
source "/home/steam/server/helper_functions.sh"

get_steamid(){
    local player_info="${1}"
    echo "${player_info: -17}"
}

get_playername(){
    local player_info="${1}"
    echo "${player_info}" | sed -E 's/,([0-9]+),[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]//g'
}

# Wait until rcon port is open
while ! nc -z 127.0.0.1 "${RCON_PORT}"; do
    sleep 5
    LogInfo "Waiting for RCON port to open to show player logging..."
done

while true; do
    server_pid=$(pidof PalServer-Linux-Test)
    if [ -n "${server_pid}" ]; then
        # Player IDs are usally 9 or 10 digits however when a player joins for the first time for a given boot their ID is temporary 00000000 (8x zeros) while loading
        # Player ID is also 00000000 (8x zeros) when in character creation
        mapfile -t current_player_list < <( get_players_list | tail -n +2 | sed '/,00000000,[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/d' | sort )

        # If there are current players then some may have joined
        if [ "${#current_player_list[@]}" -gt 0 ]; then
            # Get list of players who have joined
            mapfile -t players_who_joined_list < <( comm -13 \
                <(printf '%s\n' "${old_player_list[@]}") \
                <(printf '%s\n' "${current_player_list[@]}") )
        fi

        # If there are old players then some may have left
        if [ "${#old_player_list[@]}" -gt 0 ]; then
            # Get list of players who have left
            mapfile -t players_who_left_list < <( comm -23 \
                <(printf '%s\n' "${old_player_list[@]}") \
                <(printf '%s\n' "${current_player_list[@]}") )
        fi

        # Notify Discord and log all players who have left
        for player in "${players_who_left_list[@]}"; do
            player_name=$( get_playername "${player}" )
            LogInfo "${player_name} has left"
            broadcast_command "${player_name} has left"
			DiscordMessage "Player Left" "${DISCORD_PLAYER_LEAVE_MESSAGE}" "failure"
        done

        # Notify Discord and log all players who have joined
        for player in "${players_who_joined_list[@]}"; do
            player_name=$( get_playername "${player}" )
            LogInfo "${player_name} has joined"
            broadcast_command "${player_name} has joined"
			DiscordMessage "Player Joined" "${DISCORD_PLAYER_JOIN_MESSAGE}" "success"
        done

        old_player_list=("${current_player_list[@]}")
        players_who_left_list=( )
        players_who_joined_list=( )
    fi
    sleep "${PLAYER_LOGGING_POLL_PERIOD}"
done
