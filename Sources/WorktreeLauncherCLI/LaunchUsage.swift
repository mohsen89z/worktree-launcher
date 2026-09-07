public enum LaunchUsage {
    public static let text = """
    wt-launch - register and control long-running dev apps owned by Worktree Launcher

    USAGE
      wt-launch <command> [options]

    COMMANDS
      register            Register an app/stack for a worktree and optionally start it
      list                Show tracked apps (all, or scoped with --cwd)
      start <id|name>     Start a registered app that is not running
      stop <id|name>      Stop every process in the record, keep the record
      restart <id|name>   Replace every process; keeps id, labels, and ports
      open <id|name>      Open the record's first web app in the browser
      logs <id|name>      Print the captured log tail
      remove <id|name>    Delete launcher metadata only; never touches repos or worktrees
      help                Show this text (also --help, -h)

    REGISTER OPTIONS
      --name <name>          Record name, one per app per worktree (required)
      --cwd <path>           Absolute worktree/repo path the commands run in (required)
      --command <cmd>        Dev command; repeat once per process/microservice (required)
      --web-app <Label=URL>  Browser app to surface; repeat per app, e.g. "Web=http://localhost:3000"
      --port <port>          Port this record claims; repeat per port
      --url <url>            Single URL shorthand when there is only one web app
      --tag <tag>            Free-form tag; repeat as needed
      --start                Start the processes immediately after registering

    LIST OPTIONS
      --cwd <path>           Only records for that worktree

    LOGS OPTIONS
      --lines <n>            Lines of tail to print (default 200)

    WORKFLOW
      Check before you launch; a worktree gets one record per app:
        wt-launch list --cwd "$PWD"

      Reuse what exists instead of registering a second record:
        wt-launch restart <id>

      Register a multi-service stack with labeled web apps:
        wt-launch register \\
          --name local-stack \\
          --cwd "$PWD" \\
          --command "npm run dev:web" \\
          --command "npm run dev:api" \\
          --web-app "Web=http://localhost:3000" \\
          --web-app "API=http://localhost:4000" \\
          --port 3000 --port 3001 \\
          --start

    NOTES
      You choose ports. Registration is refused when a port is already claimed by
      another record or bound by another process, and the error suggests a free one.
      Registration is also refused when this worktree already has a record for the
      app; restart that record instead.

    FILES
      Registry  ~/Library/Application Support/Worktree Launcher/registry.json
      Logs      ~/Library/Logs/Worktree Launcher/<record-id>.log
      API       http://127.0.0.1:17678
    """
}
