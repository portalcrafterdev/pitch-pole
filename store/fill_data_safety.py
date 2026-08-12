#!/usr/bin/env python3
"""Fill Google Play's Data safety CSV for Pitchpole.

    python3 store/fill_data_safety.py <sample.csv> <out.csv>

The sample Play hands out ships with example answers in it (Name and
Approximate location, with purposes that have nothing to do with this app).
Editing it by hand means 783 rows of opportunity to leave one of those behind,
so this clears every answer first and then sets only what is true, from one
table at the top of the file.

What that table is derived from, rather than guessed:

  * Google publishes the Mobile Ads SDK's own disclosure at
    developers.google.com/admob/android/privacy/play-data-disclosure, mapped to
    Play's data types. Those four rows are the whole of what this app collects,
    because the app itself sends nothing anywhere.

  * Pitchpole has no analytics, no crash reporting and no backend. Progress and
    settings are written to the device with shared_preferences and stay there.
    Play defines collection as transmitting data off the device, so none of
    that is declarable.

  * Signing in to Play Games returns a display name, which the game stores on
    the device to show on the button. It is never transmitted, so by the same
    definition it is not collected and Personal info is not declared. This is
    the one judgement call in here worth re-reading before submitting.
"""

import csv
import sys

# Play data type -> (collection purposes, sharing purposes)
#
# Every one of these is collected AND shared, not ephemeral, and required
# rather than optional: the app offers no in-app control over any of it, which
# is what Play means by optional.
ADMOB = {
    'PSL_APPROX_LOCATION': (
        ['PSL_ADVERTISING', 'PSL_ANALYTICS', 'PSL_FRAUD_PREVENTION_SECURITY'],
        ['PSL_ADVERTISING', 'PSL_ANALYTICS', 'PSL_FRAUD_PREVENTION_SECURITY'],
    ),
    'PSL_USER_INTERACTION': (
        ['PSL_ADVERTISING', 'PSL_ANALYTICS'],
        ['PSL_ADVERTISING', 'PSL_ANALYTICS'],
    ),
    'PSL_PERFORMANCE_DIAGNOSTICS': (
        ['PSL_ANALYTICS', 'PSL_APP_FUNCTIONALITY'],
        ['PSL_ANALYTICS', 'PSL_APP_FUNCTIONALITY'],
    ),
    'PSL_DEVICE_ID': (
        ['PSL_ADVERTISING', 'PSL_ANALYTICS', 'PSL_FRAUD_PREVENTION_SECURITY'],
        ['PSL_ADVERTISING', 'PSL_ANALYTICS', 'PSL_FRAUD_PREVENTION_SECURITY'],
    ),
}

# Top level answers, as (question id, response id or None) -> value.
TOP_LEVEL = {
    # AdMob collects, so yes.
    ('PSL_DATA_COLLECTION_COLLECTS_PERSONAL_DATA', ''): 'true',
    # Google states the Mobile Ads SDK encrypts in transit with TLS, and the
    # app sends nothing of its own.
    ('PSL_DATA_COLLECTION_ENCRYPTED_IN_TRANSIT', ''): 'true',
    # There is no account in this app. Play Games sign in uses an account the
    # player already has and creates nothing here.
    ('PSL_SUPPORTED_ACCOUNT_CREATION_METHODS', 'PSL_ACM_NONE'): 'true',
    # No deletion request route, because there is nothing held to delete: the
    # app has no server. In-app reset and uninstall both clear the device.
    ('PSL_SUPPORT_DATA_DELETION_BY_USER', 'DATA_DELETION_NO'): 'true',
}


def main(src: str, dst: str) -> None:
    with open(src, newline='', encoding='utf-8') as handle:
        rows = list(csv.reader(handle))

    header, body = rows[0], rows[1:]
    out = []

    for question, response, _value, requirement, label in body:
        value = ''  # every sample answer is dropped first

        if (question, response) in TOP_LEVEL:
            value = TOP_LEVEL[(question, response)]

        elif question.startswith('PSL_DATA_TYPES_'):
            if response in ADMOB:
                value = 'true'

        elif question.startswith('PSL_DATA_USAGE_RESPONSES:'):
            _, data_type, tail = question.split(':', 2)
            if data_type in ADMOB:
                collect, share = ADMOB[data_type]
                if tail == 'PSL_DATA_USAGE_COLLECTION_AND_SHARING':
                    # Both flags true is how the sample expresses "collected
                    # and shared" rather than one or the other.
                    value = 'true'
                elif tail == 'PSL_DATA_USAGE_EPHEMERAL':
                    value = 'false'
                elif tail == 'DATA_USAGE_USER_CONTROL':
                    value = ('true' if response ==
                             'PSL_DATA_USAGE_USER_CONTROL_REQUIRED' else '')
                elif tail == 'DATA_USAGE_COLLECTION_PURPOSE':
                    value = 'true' if response in collect else ''
                elif tail == 'DATA_USAGE_SHARING_PURPOSE':
                    value = 'true' if response in share else ''

        out.append([question, response, value, requirement, label])

    with open(dst, 'w', newline='', encoding='utf-8') as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        writer.writerows(out)

    answered = sum(1 for r in out if r[2])
    print(f'{dst}: {len(out)} rows, {answered} answered')
    for row in out:
        if row[2]:
            print(f'  {row[2]:6} {row[0]}  {row[1]}')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
