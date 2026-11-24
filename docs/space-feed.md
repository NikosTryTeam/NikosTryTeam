# Space radar automation

The profile shows six recent linked headlines from the official NASA and ESA RSS feeds.
Only titles, source names, publication dates and links are copied, never full articles.

## Cadence

GitHub Actions checks daily at 09:37 UTC. A stable selection based on the current
UTC week chooses two to four different weekdays for updates. The days and count
change between weeks. Scheduled runs can be delayed or skipped by GitHub.
Manual runs and changes to the updater also trigger a refresh.

A commit is made only when the displayed headlines change. No empty commits,
backdating, timestamp-only edits or fabricated development history are generated.
If a source is unavailable, the previous feed is kept and the run reports failure.

## Attribution and contributions

Updates use Nikos's GitHub-provided noreply author address, with github-actions[bot]
as committer. Every automatic commit is explicitly labelled as an RSS update.
Because changes land on this account's standalone repository default branch,
they can count as profile contributions. GitHub controls counting and may take
up to 24 hours to display them. This activity represents automation, not manual coding.

No personal access token or external subscription is required. The built-in token
has write access only for the update job in this repository.

## Controls

- Run now: Actions -> Update space radar -> Run workflow.
- Stop: Actions -> Update space radar -> Disable workflow.
- Edit sources or the weekly cadence in `scripts/update-space-feed.ps1`.
- Text outside the SPACE-FEED markers is preserved.

GitHub can disable scheduled workflows in a public repository after 60 days
without repository activity. If that happens, re-enable the workflow in Actions.

Sources: <https://www.nasa.gov/feed/> and <https://www.esa.int/rssfeed/TopNews>.
