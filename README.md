# Skills

Claude Code skills for writing. Two of them.

## unslop

Strips the patterns that make text read as machine-written, then puts a voice back in.
Covers 31 tells across content, language, style, filler and jargon: puffery, AI vocabulary,
em dashes, inline-header lists, title case headings, passive voice, abstract metaphor nouns.

It is marked `Must always apply`, so it fires on any writing task without being asked.

## linear-task

Rewrites a Linear issue for the person who reads it, which is a PM in a list view on a phone.

One rule: anything checkable by opening the app stays in the description, anything checkable
only by opening the repo moves to a comment. Commit hashes, file paths and CI results move.
Nothing is deleted.

Ships with templates for opening and closing a ticket, a translation table from
engineer-speak to what a client actually gets, and a 350 word cap. It calls `unslop` too,
because voice and audience are separate problems.

Needs the Linear MCP server for `get_issue`, `save_comment` and `save_issue`.

## Install

Copy or symlink a skill folder into `~/.claude/skills/` for every project, or into
`.claude/skills/` inside one repo.

```bash
git clone https://github.com/hifisaputra/skills.git
ln -s "$PWD/skills/unslop" ~/.claude/skills/unslop
ln -s "$PWD/skills/linear-task" ~/.claude/skills/linear-task
```

Claude picks a skill up from its `description`, so no other wiring is needed.

## License

MIT
