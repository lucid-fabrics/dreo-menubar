# App Review information (not yet active)

This folder is deliberately named `review_information.pending`, NOT
`metadata/review_information`, so that `deliver` ignores it.

The moment a `review_information` folder exists under `fastlane/metadata/`, deliver tries to
write the App Review contact record, and Apple then requires the FULL contact set. A partial
folder fails the whole CD job with:

    You must provide a value for the attribute 'contactPhone'
    The phone number must be in a valid format. Preface the phone number with '+'
    followed by the country code (for example, +44 844 209 0611)

## To activate

1. Replace every `FILL ME IN` below with a real value:

   | File | Notes |
   |---|---|
   | `first_name.txt` / `last_name.txt` | App Review contact |
   | `phone_number.txt` | must start with `+` and a country code |
   | `email_address.txt` | App Review contact |
   | `demo_user.txt` | a Dreo account **with a fan bound to it** |
   | `demo_password.txt` | password for that account |
   | `notes.txt` | already written, explains the hardware dependency |

2. Move it into place:

       git mv fastlane/review_information.pending fastlane/metadata/review_information

3. Push, or run `bundle exec fastlane mac push_metadata`.

The demo account matters more than it looks. Windbar controls physical hardware, so a reviewer
with no Dreo fan sees an empty list and can reject under guideline 2.1 (App Completeness).
`notes.txt` exists to pre-empt exactly that.
