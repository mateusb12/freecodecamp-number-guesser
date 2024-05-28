#!/bin/bash

DB_NAME="number_guess"
DB_USER="freecodecamp"
DB_HOST="localhost"
RECREATE_DATABASE=False

setup_database() {
    psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" > /dev/null
    psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;" > /dev/null
    psql -U "$DB_USER" -d "$DB_NAME" -c "CREATE TABLE IF NOT EXISTS users (
        username VARCHAR(22) PRIMARY KEY,
        games_played INT NOT NULL,
        best_game INT NOT NULL
    );" > /dev/null
}

generate_secret_number() {
    echo $(( RANDOM % 1000 + 1 ))
}

if [ "$RECREATE_DATABASE" = "True" ]; then
    setup_database
fi

echo "Enter your username:"
read USERNAME

if [ ${#USERNAME} -gt 22 ]; then
    echo "Username should be 22 characters or less. Exiting."
    exit 1
fi

user_data=$(psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT username, games_played, best_game FROM users WHERE username='$USERNAME';" | xargs)

if [ -n "$user_data" ]; then
    IFS='|' read -ra user_arr <<< "$user_data"
    games_played=$(echo "${user_arr[1]}" | xargs)  # Trim spaces
    best_game=$(echo "${user_arr[2]}" | xargs)    # Trim spaces
    echo "Welcome back, $USERNAME! You have played $games_played games, and your best game took $best_game guesses."
else
    echo "Welcome, $USERNAME! It looks like this is your first time here."
    games_played=0
    best_game=1000
fi

secret_number=$(generate_secret_number)
echo "Guess the secret number between 1 and 1000:"

# Game loop
number_of_guesses=0
while true; do
    read -p "Enter your guess: " guess

    # Check if the input is an integer
    if ! [[ "$guess" =~ ^[0-9]+$ ]]; then
        echo "That is not an integer, guess again:"
        continue
    fi

    number_of_guesses=$(( number_of_guesses + 1 ))

    if [ "$guess" -lt "$secret_number" ]; then
        echo "It's higher than that, guess again:"
    elif [ "$guess" -gt "$secret_number" ]; then
        echo "It's lower than that, guess again:"
    else
        echo "You guessed it in $number_of_guesses tries. The secret number was $secret_number. Nice job!"
        break
    fi
done

# Update user data
games_played=$(( games_played + 1 ))
if [ "$number_of_guesses" -lt "$best_game" ]; then
    best_game=$number_of_guesses
fi

# Save the updated data back to the database
if [ -n "$user_data" ]; then
    # Update existing user data
    psql -U "$DB_USER" -d "$DB_NAME" -c "UPDATE users SET games_played=$games_played, best_game=$best_game WHERE username='$USERNAME';" > /dev/null
else
    # Add new user data
    psql -U "$DB_USER" -d "$DB_NAME" -c "INSERT INTO users (username, games_played, best_game) VALUES ('$USERNAME', $games_played, $best_game);" > /dev/null
fi
