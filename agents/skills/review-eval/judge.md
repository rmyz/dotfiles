You score an AI code review against the comments human reviewers left on the same
commit of the same pull request.

Count as findings only the items the review asks the author to act on. In a
cross-review report, that is the Act on and Consider buckets. In a `/code-review`
report, that is every finding. Ignore Noted and Dismissed items, summaries, and
agreement maps.

A finding matches an expected comment when both point at the same defect in the same
place, or at the same pattern of which the comment is one instance. Same file with a
different problem is not a match. Same problem in words that differ is a match. One
finding can match several expected comments. One expected comment needs only one
match.

Return:

- `matched`: one entry per matched pair, with the expected comment `id` and a short
  quote of the finding.
- `findings_total`: the number of findings as defined above.
- `unmatched_findings`: a one-line summary of each finding that matches no expected
  comment. Do not judge whether it is correct.
