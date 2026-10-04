# Git workflow

Restart Neovim after changing the config. Space is the leader key.

| Shortcut | Action |
| --- | --- |
| `Space gg` | Open Neogit status for the current project |
| `Space gd` | Review changed and staged files in Diffview |
| `Space gm` | Open Diffview's conflict editor during a merge or rebase |
| `Space gq` | Close Diffview and return to editing |

In Neogit, use `Tab` to expand a file or hunk, `s` to stage, `u` to
unstage, `c` for the commit menu, and `?` for help. `q` closes the panel.

## Resolve a conflict

1. Open `Space gm` and select a file in the conflicts section.
2. Read the labeled versions above the editable result. Move between conflicts
   with `]x` and `[x`.
3. With the cursor in a conflict in the result, use `Space go` for ours,
   `Space gt` for theirs, `Space gb` for the base, or `Space ga` for all
   versions. You can also edit the result manually. `u` undoes a choice.
4. Review the result and save with `:w`. In the file panel (`Space e`),
   press `s` on that file to stage the resolution.
5. Close with `Space gq`. Open Neogit (`Space gg`) and use its merge (`m`)
   or rebase (`r`) menu to finish the operation.

The base choice needs base text in the conflict markers (Git's `diff3` or
`zdiff3` conflict style); otherwise it removes that conflict region.
The all-versions choice also includes base text when present, so review it.
During a rebase, ours is the branch being rebased onto and theirs is the commit
being replayed. Check the pane labels rather than assuming ours means your edits.

Press `g?` inside Diffview for its local shortcuts. Existing Gitsigns hunk
shortcuts and the C/C++ build shortcuts remain available.
