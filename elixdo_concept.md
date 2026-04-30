This will be a project written in Elixir, Phoenix LiveView. One of the main goals of the project is to demonstrate an elixir app. 

This will be a todo app. To be successful, it must be good enough to pull me away from the paper system that I have used for years. Paper has several advantages for todo lists. It is nearly always available; The input format is very flexible; it creates an enduring record; 

Disadvantages of paper: I lose the paper with the most important notes. The list is not visible to others. 

To overcome the problems I have had in the past with adopting todo lists, this project will have these interesting features. 

1. The list can be accessed from any computer or phone with web access.  
2. Anyone with access can read and edit.  
3. The friction to logon is extremely low. Secret URL plus a static bearer token for AI agents.   
4. Each day will have its own list. Lists are not deleted. List items are not deleted.  
5. Past, present and future lists can be edited.  
6. Paging forward and backward through lists will be simple and responsive.I am imaging something similar to paging through photos is quick and responsive.    
   App will respond to swiping where available. Also to arrow keys, where available. Also clicks on the arrow icons on the left and right of the screen. Left=Past, Right=Future.

7. There is a second navigation method to allow jumping to days that are distant; weeks, months, years away.  
8. When the current page is not today, then there is a "Return to Today” button.This will be an icon that does not get in the way. 

9. List items are not normally deleted. Instead, they are crossed out when completed, wiggled out when abandoned, arrowed out when pushed forward to another day.  
   Wiggled out is what I do on paper. I run a scribbly line through the item to show that it is not to be considered anymore and that it was not accomplished. If the wiggly line is too difficult to produce, then some other marking can be chosen, like a double strikethrough.  
   Arrowed out means the text is struck thru with an arrow pointing right (toward the future)

| State | Approach |
| :---- | :---- |
| completed | text-decoration: line-through |
| wiggled\_out | text-decoration: line-through wavy |
| arrowed\_out | text-decoration: line-through \+ ::after { content: ' →' } |

Start with all three as pure CSS. The appended arrow character is not exactly "through the text" but it communicates the meaning instantly and requires zero JavaScript.  These three decorators are always black, even if the text is some other color. The arrow will be bold and \+4 font sizes to make it more visible.

10. The arrowed-out action prompts for a future date. A copy of the item, are put on that date. The item remains on the current list (which might not be today) and the text is struck-thru with an arrow point towards the right. There is no link between the item and the pushed item. Either can be edited independently from the other.  
      
11. List items can be decorated with numbers, letters, emoji and icons. Or emboldened, italicized, or highlighting. These will indicate some type of ill-defined priority or attention getting mechanism.  The numbers, letters, emoji, icons will be added in the area around the selection button.  Emboldening, italicizing and highlighting happen to the text. Highlighting makes the background yellow.

12. Each list item will be prefixed with a selection button (perhaps an open circle). When selected, the next decoration action will affect it. There will be a “Select All” button above the list that will not scroll away.

13. List items can be color coded within a small palette of bright, easily distinguished colors. The color will be applied to the whole item. The pallet is:

        red    \= Color(0xFFE53935),  // Ruby

   	    blue   \= Color(0xFF1E88E5),  // Sapphire  
    green  \= Color(0xFF43A047),  // Emerald  
    purple \= Color(0xFF8E24AA),  // Amethyst  
    orange \= Color(0xFFFB8C00)   // Tangerine

14. The decorator actions and the color palette will be a fixed toolbar of buttons at the top of the screen.  The toolbar does not show the state of an item. It shows the available decorator actions. Clicking one invokes that action on all selected list items.

    The forward-arrow action will prompt for a single date. All selected list items are copied to that date.

15. List items can be rearranged. There will be drag handles. That should be usable on web and Android versions.  
      
      
16. List items can be added by typing, by voice, or by photo of a text note. 

     Voice input will only be implemented for Android. I don’t have a use case for talking into a windows machine.

    For OCR, It is ok to send the photos to a third party. And it is ok for this to have a cost. I will provide an API key for OpenAI. THere may be several items in a photo of a white board. SPlit them into separate list items. Results go on the current screen, which may not be Today. There is no need to confirm the OCR, it will go into the app where it can be examined and edited, if needed.

17. List items can be multi-line entries. Shift-Enter gives a new line. Enter submits the item.

18. There are no timers or alarms in the app. It is not a calendar or an appointment tracker, even though an appointment could be listed as a todo item.  
      
19. The database used for the lists is undecided. It must integrate easily with elixir and its stack.SQLite via *Ecto \+ Exqlite*. Zero infrastructure, easy backup (it's one file), and Fly.io gives you a persistent volume.   
20. The database of list items will be searchable. Clicking a result navigates to that day's list and highlights the item.  
    A dedicated SearchIndex GenServer owns the ETS table and is started by the application supervisor at boot. Because it owns the table, the table lives as long as the GenServer — which is as long as the app is running.   
    The index is not saved between sessions. ETS is fast enough for the size of the db that users will not notice.  
    No periodic full rebuilds needed — the index stays current incrementally. The SearchIndex GenServer also needs to stay current as items are created or edited. The cleanest approach is to have your context functions cast to it after writes:   
      
21. The app will be accessible by my AI agents. There will be an api with token. (Agent API via a lightweight Plug endpoint — A separate /api scope with token auth, returning JSON. Since your LiveView process already holds list state, the API just calls into the same GenServer — no duplication of logic. )  
    Here are use cases for the AI through the API:  
    An agent could add items to today's list after a meeting ("add 'follow up with John' to today")  
    1. An agent could read your list to understand your current priorities before helping you plan  
    2. An agent could mark things complete or push items forward after you describe what happened in your day  
    3. A morning script could pull yesterday's incomplete items and summarize them

    

22. There is no need to show presence or live cursors of other users in the file.  
23. There is no plan to schedule tasks, so I don’t see a need for Oban  
24. The time zone used will be **The IANA timezone identifier *America/Denver***.  
    If the app is running at midnight, which will almost always be the case, the internal variable for TODAY will update. The screen will not jump to the new day. The user will do that when he wakes up.   
    There may need to be a reload for the GenServer. Evaluate this.  
25. There is no automatic carry forward of list items from one day to the next. However, tomorrow’s list any day the future or past can exist in the database and might have been populated ahead of time, so new days do not necessarily start the day blank.  
      
26. Progressive Web App. Meant to enable multi platform access. Challenge this if it makes the project more complicated and adds friction.

Implementation choices that are elixir leveraged. These are ideas to explore in the development process. They are listed here so their consideration is not missed.

- \- it may be useful to plan on per-list GenServer processes to give the snappy photo-flip feel.  
- \- PubSub may be useful for real-time multi-device sync.  
- \- The search function can be ETS-backed fast search. (Store a search index in ETS (Erlang Term Storage, in-memory, built into the VM). Search is sub-millisecond with no external search service. )  How often will the index be rebuilt? Will it be saved between sessions? Can it be saved?  There are more decisions to be made on search. This feature will be added late in development, but remember that it is coming so as not to block its implementation.  
- DynamicSupervisor for per-list GenServers. The per-list GenServer idea is good, but it needs a supervision strategy. A DynamicSupervisor starts list processes on demand and a via registry looks them up by date. Idle lists shut themselves down after a configurable inactivity timeout via Process.send\_after.   
- GenServer as the write buffer. The GenServer holds the list in memory. Writes go to the GenServer immediately (instant UI response via PubSub), then the GenServer persists to SQLite asynchronously. Dirty state is flushed on a short timer or on process shutdown. This gives you the snappy feel even on slow storage.

Access Design

1. There is going to be one account used by several people and the AI.    
2. The lists are shared. Everyone reads and edits .     
3. A session is expected to stay active for weeks or months so no one has to login.   
4. Last Write wins.  
5. Secret URL plus a static bearer token for AI agents. https://your-app.fly.dev/Zq3mK9vR2xNpL8wY4tFjB6cHdA1eGs7u  
   The url will be hosted on [fly.io](http://fly.io) . A non-obvious urls will be assigned. Example:  
   https://your-app.fly.dev/Zq3mK9vR2xNpL8wY4tFjB6cHdA1eGs7u  
     
     
   If the secret ever leaks: fly secrets set SECRET\_PATH=\<new-value\>, redeploy, update bookmarks.   
   

**Starting place for a data model.**

list\_items

| Column | Type | Notes |
| :---- | :---- | :---- |
| id | bigint (PK) | Auto-increment |
| date | date | Which day's list. Indexed. |
| position | integer | Sort order within the day. |
| body | text | The item text. |
| status | enum | active | completed | wiggled\_out | arrowed\_out |
| color | enum | nil | red | blue | green | purple | orange |
| bold | boolean | Default false. |
| italic | boolean | Default false. |
| highlighted | boolean | Default false. Yellow background. |
| prefix | string | Nullable. Letter, number, emoji, or icon identifier. |
| arrowed\_to\_date | date | Nullable. Set when status is arrowed\_out. |
| inserted\_at | utc\_datetime |  |
| updated\_at | utc\_datetime |  |

---

## Indexes

CREATE INDEX idx\_list\_items\_date\_position ON list\_items (date, position);  
CREATE VIRTUAL TABLE list\_items\_fts USING fts5(body, content='list\_items', content\_rowid='id');

---

## Ecto Schema

schema "list\_items" do  
  field :date,            :date  
  field :position,        :integer  
  field :body,            :string  
  field :status,          Ecto.Enum, values: \[:active, :completed, :wiggled\_out, :arrowed\_out\],  
                                     default: :active  
  field :color,           Ecto.Enum, values: \[:red, :blue, :green, :purple, :orange\]  
  field :bold,            :boolean,  default: false  
  field :italic,          :boolean,  default: false  
  field :highlighted,     :boolean,  default: false  
  field :prefix,          :string  
  field :arrowed\_to\_date, :date

  timestamps(type: :utc\_datetime)  
end

Here's the full API contract:

---

## **Auth**

Authorization: Bearer elix\_agt\_s3cr3tt0k3nhere

All /api/\* routes require this header. Missing or invalid → 401.

---

## **Date Handling**

Accepted anywhere a date is expected:

| Value | Resolves to |
| ----- | ----- |
| today / yesterday / tomorrow | Server-side in America/Denver |
| 2026-04-29 | ISO 8601 literal |

Responses always return resolved ISO 8601 strings, never relative terms.

---

## **Error Envelope**

{  
  "error": {  
    "code": "validation\_error",  
    "message": "Request body contains invalid fields.",  
    "details": { "status": \["is not a valid status"\] }  
  }  
}

| Status | Code | When |
| ----- | ----- | ----- |
| 400 | bad\_request | Malformed JSON |
| 401 | unauthorized | Bad/missing token |
| 404 | not\_found | Item doesn't exist |
| 409 | conflict | Forbidden status transition |
| 422 | validation\_error | Field validation failure |
| 500 | internal\_error | Server error |

---

## **Routes**

| Method | Path | Description |
| ----- | ----- | ----- |
| GET | /api/v1/lists/:date | All items for one day |
| GET | /api/v1/lists?from=\&to=\&status= | Items across a date range |
| POST | /api/v1/lists/:date/items | Create one or more items |
| PATCH | /api/v1/items/:id | Update fields on one item |
| POST | /api/v1/items/:id/arrow | Arrow item to another date |
| PATCH | /api/v1/lists/:date/reorder | Reorder all items for a day |

---

### **GET /api/v1/lists/:date**

Returns all items sorted by position ascending. An empty list is 200, not 404.

{  
  "date": "2026-04-29",  
  "items": \[  
    {  
      "id": 1,  
      "date": "2026-04-29",  
      "position": 1,  
      "body": "Review PR from Jordan",  
      "status": "active",  
      "color": null,  
      "bold": false,  
      "italic": false,  
      "highlighted": false,  
      "prefix": null,  
      "arrowed\_to\_date": null,  
      "inserted\_at": "2026-04-29T07:14:00Z",  
      "updated\_at": "2026-04-29T07:14:00Z"  
    }  
  \]  
}

---

### **GET /api/v1/lists?from=\&to=\&status=**

Date range query. status is optional, comma-separated filter. Every date in range is included even if empty.

GET /api/v1/lists?from=2026-04-21\&to=yesterday\&status=active,wiggled\_out

{  
  "from": "2026-04-21",  
  "to": "2026-04-28",  
  "days": \[  
    { "date": "2026-04-21", "items": \[\] },  
    { "date": "2026-04-22", "items": \[ { "id": 7, "body": "Call insurance", "status": "active", "..." : "..." } \] }  
  \]  
}

---

### **POST /api/v1/lists/:date/items**

Creates one or more items atomically (all or nothing). Items appended after existing positions. status and position are not accepted — assigned automatically.

{  
  "items": \[  
    { "body": "Follow up with Sarah", "color": "blue" },  
    { "body": "Send meeting notes", "highlighted": true }  
  \]  
}

Returns 201 with the created items including assigned id and position.

---

### **PATCH /api/v1/items/:id**

Partial update — only fields present are changed.

{ "status": "completed", "color": "green" }

**Status transition rules:**

* active → anything allowed  
* completed or wiggled\_out → back to active allowed (undo)  
* arrowed\_out → no transitions, frozen. Returns 409.

---

### **POST /api/v1/items/:id/arrow**

Two atomic writes: original gets arrowed\_out \+ arrowed\_to\_date set; a copy is appended to the target date with status: active. No FK link between them. Only active items can be arrowed — others return 409.

{ "to\_date": "tomorrow" }

Response includes both original and copy objects. The copy inherits body, color, bold, italic, highlighted, prefix. It does not inherit position or arrowed\_to\_date.

---

### **PATCH /api/v1/lists/:date/reorder**

Atomically sets position for every item on the day. Must include all item IDs for that date — partial lists rejected with 422.

{ "order": \[7, 2, 1, 42, 43\] }

First ID gets position: 1, and so on. Returns the full reordered list.

---

## **Implementation Notes**

* All timestamps in responses are UTC with Z suffix  
* Denver timezone only affects relative date term resolution  
* Arrow and reorder operations must use database transactions  
* Bulk POST must be atomic — all items or none  
* Position values must be unique per date but need not be contiguous

