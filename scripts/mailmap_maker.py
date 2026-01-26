#!/usr/bin/env python3

# https://gist.github.com/AddisonG/ae0572b380af3c51bfdcb738f86bd717
"""
Run this like:

cd /my/git/dir/
git shortlog -s -n -e | python3 ~/mailmap.py > .mailmap
"""

import sys


NAMES_TO_EMAILS = dict()
EMAILS_TO_NAMES = dict()


def get_all_names(email):
    visited_names = set()
    visited_emails = set()
    to_visit = [email]

    while to_visit:
        current_email = to_visit.pop()
        visited_emails.add(current_email)
        for name in EMAILS_TO_NAMES.get(current_email, set()):
            if name not in visited_names:
                visited_names.add(name)
                to_visit.extend(NAMES_TO_EMAILS.get(name, set()) - visited_emails)

    return visited_names


def main(input_stream):
    for line in input_stream:
        _, name_email = line.strip().split("\t", 1)
        name, email = name_email.split(" <")
        email = email.strip(">").lower()

        # Map names to emails
        if name not in NAMES_TO_EMAILS:
            NAMES_TO_EMAILS[name] = set()
        NAMES_TO_EMAILS[name].add(email)

        # Map emails to names
        if email not in EMAILS_TO_NAMES:
            EMAILS_TO_NAMES[email] = set()
        EMAILS_TO_NAMES[email].add(name)

    while EMAILS_TO_NAMES:
        # Pick a random email and name, to use as the "real" one
        random_email = next(iter(EMAILS_TO_NAMES))
        random_name = sorted(EMAILS_TO_NAMES[random_email])[0]

        # Get all other usernames for it
        all_names = get_all_names(random_email)

        # Get all other email/usernames, and map them to the original email
        keys_to_delete = set([random_email])

        for other_name in all_names:
            for other_email in NAMES_TO_EMAILS[other_name]:
                if random_email == other_email and random_name == other_name:
                    continue
                print(f"{random_name} <{random_email}> {other_name} <{other_email}>")
                keys_to_delete.add(other_email)

        # Remove the email, and all connected emails
        for key in keys_to_delete:
            del EMAILS_TO_NAMES[key]


if __name__ == "__main__":
    main(sys.stdin)
