#!/bin/bash
# This script updates the adblock list from hagezi's ultimate blocklist.
# It validates the downloaded file and asks the user for confirmation.
# If confirmed, it merges the original hosts file with the downloaded file.

BLOCKLIST_URL="https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/hosts/ultimate.txt"

main() {
    # Check if /etc/hosts.org exists
    if [ ! -f /etc/hosts.org ]; then
        exit_error "/etc/hosts.org does not exist. Please create it and try again."
    fi

    echo "Updating adblock list (hagezi ultimate) ..."
    # Download the file to a secure temporary location
    temp_file=$(mktemp)

    trap '[ -f "$temp_file" ] && rm -f "$temp_file"' INT TERM EXIT

    if ! curl -fsS -o "$temp_file" "$BLOCKLIST_URL"; then
        exit_error "Failed to download the adblock list. Exiting."
    fi

    # Validate the downloaded file
    validate_download "$temp_file"

    # Display the header information of the downloaded blocklist
    show_header "$temp_file"

    # Ask the user if they want to apply the downloaded adblock list
    read -p "Do you want to apply the downloaded adblock list? (y/n) " -n 1 -r
    echo    # move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Merge /etc/hosts.org with the downloaded file
        cat /etc/hosts.org "$temp_file" > /etc/hosts
        echo "The downloaded adblock list was applied."
    else
        echo "The downloaded adblock list was not applied."
    fi
}

show_header() {
    local temp_file="$1"
    echo
    awk '/^# *$/ {next}
    /^#/ {
        gsub("# ", "");
        split($0, arr, ":");
        printf "\033[1m%s:\033[0m%s\n", arr[1], substr($0, length(arr[1])+2);
        next
    }
    !/^#/ {exit}' "$temp_file"
    echo
}

validate_download() {
    local temp_file="$1"
    # Check if the file size is larger than 10MB
    if [ "$(stat -c%s "$temp_file")" -le 10485760 ]; then
        exit_error "The downloaded file is not larger than 10MB. Exiting."
    fi

    # Check if the file is a text file
    if ! file "$temp_file" | grep -q text; then
        exit_error "The downloaded file is not a text file. Exiting."
    fi

    # Check if all lines start with a comment #, 0.0.0.0, or are empty
    if ! grep -Pvq "^(#|0\.0\.0\.0|\s*)$" "$temp_file"; then
        exit_error "The downloaded file contains invalid lines. Exiting."
    fi

    # Extract the number of entries from the comment line
    entries=$(grep -oP "^# Number of entries: \K\d+" "$temp_file")

    # Count the number of lines starting with 0.0.0.0
    count=$(grep -c "^0.0.0.0" "$temp_file")

    # Compare the two numbers and throw an error if they are not equal
    if [[ "$entries" != "$count" ]]; then
        exit_error "The number of entries does not match the count of lines starting with 0.0.0.0. Exiting."
    fi
}

exit_error() {
    echo "$1"
    exit 1
}

main "$@" || exit 1
