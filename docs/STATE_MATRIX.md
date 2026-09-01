# State Matrix

## Cell presentation

| Model state | Visual | Input |
|---|---|---|
| covered | raised blank tile | reveal / mark |
| pressed | recessed blank tile | preview only |
| flagged | raised tile + red flag | unmark |
| questioned | raised tile + question mark | clear mark |
| revealed 0 | recessed empty tile | none |
| revealed 1…8 | recessed tile + number color | chord eligible |
| exploded mine | red recessed tile + mine | terminal |
| hidden mine | recessed tile + mine | terminal |
| correct flag | raised tile + flag | terminal |
| wrong flag | recessed tile + crossed mine | terminal |
| keyboard focus | high-contrast inner outline | follows focused cell |

## Face presentation

| Game/input state | Face |
|---|---|
| ready / playing | normal |
| primary press / chord preview | surprised |
| lost | dead |
| won | sunglasses |
| face button pressed | pressed normal |

## Game transitions

| From | Event | To | Side effect |
|---|---|---|---|
| ready | first valid reveal | playing | generate board; start continuous clock |
| ready | mark | ready | update remaining mine display only |
| playing | safe reveal | playing | reveal cell/flood region |
| playing | all safe cells revealed | won | stop clock; auto-show flags; eligible record write |
| playing | mine revealed | lost | stop clock; reveal terminal cell states |
| any | new game | ready | discard current board and timer |
| terminal | cell action | terminal | no-op |

## Marks option

| Change | Existing question marks | Secondary-click cycle |
|---|---|---|
| Marks on | unchanged | covered → flag → question → covered |
| Marks off | immediately converted to covered | covered ↔ flag |
