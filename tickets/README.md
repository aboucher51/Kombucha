# Tickets

One file per piece of work. Agents claim a ticket before starting, write
progress notes into it, and close it when the work is pushed. The files
are managed by the agent-tickets skill's script:

    python3 ~/.claude/skills/agent-tickets/scripts/tickets.py <command>

Run it with no arguments to see the commands. Edit ticket files by hand
freely; the script only needs the lines between the `---` markers intact.
