---
name: rails-cto-restful
description: >
  How to write RESTful controllers for this Rails 8 project.
  Use when creating, modifying, or restructuring controllers, adding new actions,
  defining routes, or designing resource hierarchies. Also use when the user
  mentions "controller", "routes", "actions", "REST", "nested resource",
  "CRUD", or asks where to put a new action. Proactively apply these rules
  whenever touching controllers or routes, even if the user doesn't explicitly
  ask about REST conventions.
---

# RESTful Controllers in This Project

Rails controllers should be thin orchestrators — they receive a request, delegate to a command/service, and respond with the right format. Every controller action maps to one of the 7 standard REST verbs. When you need behavior beyond those 7, extract a nested controller rather than adding custom actions.

## The Golden Rules

1. **Stick to the 7.** `index`, `show`, `new`, `edit`, `create`, `update`, `destroy` — nothing else.
2. **Order matters.** Always define actions in this order: index, show, new, edit, create, update, destroy.
3. **Document each action.** Every action gets a one-line comment showing its HTTP verb and route (e.g. `# GET /posts/:id`).
4. **Extract, don't extend.** Need a custom action? Make a new controller under a namespace.
5. **Load resources in before_action.** Set instance variables via callbacks, not inside each action.
6. **Use service objects for complexity.** Simple saves can stay inline; multi-step logic goes to commands.
7. **Scope to current_account.** Never load resources globally — always through `current_account`.
8. **Test every controller.** Each controller gets a test verifying response codes — not business logic.

---

## The Standard 7

Every controller should use only these actions. Define them in this exact order — it makes controllers predictable and scannable across the codebase:

| Order | Action    | Verb     | Purpose                        |
|-------|-----------|----------|--------------------------------|
| 1     | `index`   | GET      | List resources                 |
| 2     | `show`    | GET      | Display a single resource      |
| 3     | `new`     | GET      | Render a creation form         |
| 4     | `edit`    | GET      | Render an edit form            |
| 5     | `create`  | POST     | Persist a new resource         |
| 6     | `update`  | PATCH    | Modify an existing resource    |
| 7     | `destroy` | DELETE   | Remove a resource              |

Each action gets a one-line comment documenting its HTTP verb and route:

```ruby
# frozen_string_literal: true

class PostsController < ApplicationController
  before_action :authenticate
  before_action :set_post, only: [:show, :edit, :update, :destroy]

  # GET /posts
  def index
    @posts = Posts::Search.run(account: current_account, params: params)
    respond_to(:turbo_stream, :html)
  end

  # GET /posts/:id
  def show
    respond_to(:turbo_stream, :html)
  end

  # GET /posts/new
  def new
    @post = Post.new
    respond_to(:turbo_stream, :html)
  end

  # GET /posts/:id/edit
  def edit
    respond_to(:turbo_stream, :html)
  end

  # POST /posts
  def create
    result = Posts::Create.call(params: post_params, account: current_account)

    if result.success?
      @post = result.post
      respond_to(:turbo_stream, :html)
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH /posts/:id
  def update
    result = Posts::Update.run(post: @post, params: post_params.to_h)

    if result.success?
      respond_to(:turbo_stream, :html)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /posts/:id
  def destroy
    @post.discard!
    respond_to(:turbo_stream, :html)
  end

  private

  def set_post
    @post = current_account.posts.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :url, :description, :collection_id)
  end
end
```

---

## When You Need More Than 7: Extract a Nested Controller

If an action doesn't fit the standard 7, it belongs in its own controller under the parent namespace. This is the most important rule.

### The Pattern

Think of the extra behavior as a **noun**, then create a controller for that noun:

```
# Instead of adding `archive` and `unarchive` actions to PostsController:
#   WRONG: posts#archive, posts#unarchive
#
# Create separate controllers for the concept:
#   RIGHT: posts/archives#new      (GET  — confirmation UI)
#   RIGHT: posts/archives#destroy   (DELETE — perform archive)
#   RIGHT: posts/unarchives#update  (PATCH — undo archive)
```

### Real Examples From This Codebase

**FeedsController** stays clean with only the standard 7. Everything else is extracted:

```
app/controllers/
├── feeds_controller.rb                    # index, show, new, create, edit, update, destroy
└── feeds/
    ├── boards_controller.rb               # show — the feed dashboard
    ├── reading_lists_controller.rb         # show — reading list sidebar
    ├── relevant_tags_controller.rb         # show — tag sidebar widget
    └── activities_controller.rb            # show — activity feed widget
```

**PostsController** with its nested resources:

```
app/controllers/
├── posts_controller.rb                # standard 7 + pane_preview, pane_read
└── posts/
    ├── archives_controller.rb             # new, destroy — archive a post
    ├── unarchives_controller.rb           # update — restore from archive
    ├── read_controller.rb                 # show, create, update, destroy — reading state
    ├── visit_controller.rb                # show — redirect to URL + track visit
    ├── reminders_controller.rb            # create, destroy — set/clear reminders
    ├── trashes_controller.rb              # create — bulk trash
    ├── taggings_controller.rb             # update, destroy, sync — manage tags
    └── collections_controller.rb          # update — change collection
```

### How to Decide the Controller Name

Turn the verb into a noun. The noun becomes the controller:

| Verb / Action           | Noun / Controller            | Actions Used            |
|-------------------------|------------------------------|-------------------------|
| Archive a post      | `Posts::ArchivesController`    | `new`, `destroy`  |
| Unarchive a post    | `Posts::UnarchivesController`  | `update`          |
| Visit / redirect        | `Posts::VisitController`       | `show`            |
| Set a reminder          | `Posts::RemindersController`   | `create`, `destroy` |
| Mark as read            | `Posts::ReadController`        | `show`, `create`, `update`, `destroy` |
| Sync tags               | `Posts::TaggingsController`    | `update`, `destroy` + `sync` collection action |
| Refresh a feed          | would be `Feeds::RefreshesController` | `create`       |
| Toggle all feeds        | would be `Feeds::TogglesController`   | `update`       |

### Nested Controller Structure

```ruby
# frozen_string_literal: true

# Handles archiving a post — extracted from PostsController
# because "archive" is not one of the standard 7 REST actions.
class Posts::ArchivesController < ApplicationController
  before_action :authenticate
  before_action :set_post, only: [:new, :destroy]

  # GET /posts/:id/archives
  def new
    respond_to(:turbo_stream, :html)
  end

  # DELETE /posts/:id/archives
  def destroy
    command = Posts::Archive.run(post: @post)

    if command.success?
      render turbo_stream: destroy_streams_for(@post)
    end
  end

  private

  def set_post
    @post = Post.includes(:collection).find(params[:id])
  end
end
```

---

## Inheritance for Nested Controllers

Two patterns exist. Choose based on whether you need the parent's filters:

### Inherit from parent (when you need its `before_action` filters)

```ruby
# Reuses PostsController's set_post, set_tag_suggestions, etc.
class Posts::ReadController < PostsController
  before_action :authenticate
  before_action :set_post
  before_action :set_tag_suggestions, only: [:info]
end
```

### Inherit from ApplicationController (when you don't)

```ruby
# Defines its own set_post with different includes
class Posts::ArchivesController < ApplicationController
  before_action :authenticate
  before_action :set_post

  private

  def set_post
    @post = Post.includes(:collection).find(params[:id])
  end
end
```

---

## Routes

Routes mirror the controller structure. Standard resources at the top, nested resources below:

```ruby
# Standard resource
resources :feeds do
  member do
    post :refresh          # Consider extracting to Feeds::RefreshesController
    get :pane_preview
  end
  collection do
    patch :toggle_all      # Consider extracting to Feeds::TogglesController
    post :refresh_all
    get :pane_new
  end
end

# Nested resources — clean extraction
resources :posts do
  resources :taggings, controller: "posts/taggings" do
    collection do
      patch :sync
    end
  end

  member do
    get "archives",     to: "posts/archives#new"
    delete "archives",  to: "posts/archives#destroy"
    patch "unarchives", to: "posts/unarchives#update"
    get "visit",        to: "posts/visit#show"
    get "read",         to: "posts/read#show"
    post "read",        to: "posts/read#create"
    patch "read",       to: "posts/read#update"
    delete "read",      to: "posts/read#destroy"
    post "reminders",   to: "posts/reminders#create"
    delete "reminders", to: "posts/reminders#destroy"
  end
end
```

### Namespaced UI-component routes

For sidebar widgets and UI fragments that belong to a parent resource but aren't CRUD on a child resource, use `namespace`:

```ruby
namespace :feeds do
  resource :boards, only: [:show]
  resource :reading_list, only: [:show]
  resource :relevant_tags, only: [:show]
  resource :activity, only: [:show]
end
```

---

## Pane Actions

The one accepted deviation from strict REST: `pane_preview`, `pane_read`, `pane_new`, and `pane_edit` actions live on the parent controller. These render layout-less fragments for the split-pane UI and map to the same resource — they're just alternate representations of `show`, `new`, and `edit`.

```ruby
class FeedsController < ApplicationController
  def pane_preview
    render layout: false
  end

  def pane_new
    @feed = Feed.new
    @at_limit = !current_account.can_create_feed?
    render layout: false
  end
end
```

These are acceptable because they're still `show`/`new`/`edit` semantically — they just render a different layout for the side panel.

---

## Before Action Filters

Order filters from broadest to most specific:

```ruby
before_action :authenticate                                    # 1. Auth (always first)
before_action :set_post, only: [:show, :edit, :update]     # 2. Load resource
before_action :set_scope, only: [:index]                       # 3. Set context/scope
before_action :set_tag_suggestions, only: [:pane_preview]      # 4. Feature-specific data
```

### Set instance variables in before_action, not in actions

Instance variables shared across actions should be loaded via `before_action` callbacks. This eliminates duplicate loading code and keeps actions focused on their response logic.

```ruby
# CORRECT — load once, use in many actions
before_action :set_post, only: [:show, :edit, :update, :destroy, :pane_preview]

# GET /posts/:id
def show
  respond_to(:turbo_stream, :html)
end

# GET /posts/:id/edit
def edit
  respond_to(:turbo_stream, :html)
end

private

def set_post
  @post = current_account.posts.find(params[:id])
end
```

```ruby
# WRONG — loading the same resource in every action
def show
  @post = current_account.posts.find(params[:id])
  respond_to(:turbo_stream, :html)
end

def edit
  @post = current_account.posts.find(params[:id])
  respond_to(:turbo_stream, :html)
end

def update
  @post = current_account.posts.find(params[:id])
  # ...
end
```

### Resource loading always scopes to current_account

```ruby
# CORRECT — scoped to the authenticated user
def set_post
  @post = current_account.posts.find(params[:id])
end

def set_collection
  @collection = current_account.collections.find_by_hashid!(params[:id])
end

# WRONG — unscoped, any user could access any record
def set_post
  @post = Post.find(params[:id])
end
```

---

## Response Patterns

### Simple: delegate to responder

```ruby
def show
  respond_to(:turbo_stream, :html)
end
```

### With service object

```ruby
def create
  result = Feeds::Create.run(url: feed_params[:url], account: current_account)

  if result.success?
    @feed = result.feed
    respond_to(:turbo_stream, :html)
  else
    @feed = Feed.new(url: feed_params[:url])
    @error = result.errors.message_list.join(", ")
    render :new, status: :unprocessable_entity
  end
end
```

### Multiple turbo streams

When a single action needs to update multiple parts of the UI, return an array of streams:

```ruby
def destroy
  @post.discard!

  render turbo_stream: [
    turbo_stream.remove(dom_id(@post)),
    turbo_stream.update("post_pane", html: ""),
    turbo_stream.update(dom_id(current_account, :reading_list),
                        partial: "layouts/reading_list_count")
  ]
end
```

---

## When to Use Service Objects

Simple one-liner operations can stay in the controller. Once an action involves multiple steps, conditional logic, external calls, or side effects beyond a basic save, extract to a command object.

### Inline is fine for simple operations

```ruby
# Simple — no service needed
# DELETE /posts/:id
def destroy
  @post.discard!
  respond_to(:turbo_stream, :html)
end

# Simple toggle — one attribute update
# PATCH /posts/:id
def update
  @post.update!(post_params)
  respond_to(:turbo_stream, :html)
end
```

### Extract to a service when complexity grows

Instead of adding private helper methods to controllers, always prefer service objects. Controllers should be thin — they receive a request and delegate to a service. Private methods in controllers are a code smell that signals logic belongs elsewhere.

```ruby
# WRONG — private helper method in controller
private

def process_and_archive(post)
  post.update!(archived: true)
  ArchiveNotificationJob.perform_later(post)
  post.tags.each(&:update_counts!)
end

# RIGHT — extract to a service object
result = Posts::Archive.run(post: @post)
```

```ruby
# Complex — multiple steps, side effects, external calls
# POST /posts
def create
  result = Posts::Create.call(params: post_params, account: current_account)

  if result.success?
    @post = result.post
    respond_to(:turbo_stream, :html)
  else
    render :new, status: :unprocessable_entity
  end
end
```

All service objects must inherit from `ApplicationService`. Commands live in `app/commands/` and follow this pattern:

```ruby
# Commands use .run() — returns result with .success? and outputs
result = Posts::Archive.run(post: @post)
result.success?  # => true/false
result.errors    # => error object with .message_list

# Commands can also use .call()
command = Posts::Create.call(params: post_params, account: current_account)
command.post  # => the created record
```

### Signs you need a service object

- More than one model is created or updated
- Background jobs need to be enqueued
- External APIs are called
- Conditional branching determines which records to change
- The action has side effects (emails, broadcasts, cache invalidation)
- The logic would need its own tests

Controllers should **never** contain:
- Direct ActiveRecord create/update calls spanning multiple models
- Multi-step workflows
- External API calls
- Email sending
- Background job orchestration beyond a single `perform_later`

---

## Controller Tests

Every controller gets a test file that verifies response codes. Controller tests assert that routes return the correct HTTP status — they do not test business logic, which belongs in command/service tests.

### Test file structure

```ruby
# frozen_string_literal: true

require "test_helper"

class FeedsControllerTest < ActionDispatch::IntegrationTest
  let(:account) { create(:account) }
  let(:feed) { create(:feed, account: account) }

  before { sign_in(account) }

  # GET /feeds
  describe "GET #index" do
    it "returns success" do
      get feeds_path, as: :turbo_stream

      assert_response :success
    end
  end

  # GET /feeds/:id
  describe "GET #show" do
    it "returns success" do
      get feed_path(feed), as: :turbo_stream

      assert_response :success
    end
  end

  # GET /feeds/new
  describe "GET #new" do
    it "returns success" do
      get new_feed_path, as: :turbo_stream

      assert_response :success
    end
  end

  # GET /feeds/:id/edit
  describe "GET #edit" do
    it "returns success" do
      get edit_feed_path(feed), as: :turbo_stream

      assert_response :success
    end
  end

  # POST /feeds
  describe "POST #create" do
    it "returns success" do
      post feeds_path,
           params: { feed: { url: "https://example.com/feed.xml" } },
           as: :turbo_stream

      assert_response :success
    end
  end

  # PATCH /feeds/:id
  describe "PATCH #update" do
    it "returns success" do
      patch feed_path(feed),
            params: { feed: { name: "Updated" } },
            as: :turbo_stream

      assert_response :success
    end
  end

  # DELETE /feeds/:id
  describe "DELETE #destroy" do
    it "returns success" do
      delete feed_path(feed), as: :turbo_stream

      assert_response :success
    end
  end
end
```

### What controller tests DO

- Assert response codes: `assert_response :success`, `assert_response :redirect`
- Verify the response format: `assert_equal "text/vnd.turbo-stream.html", response.media_type`
- Check record count changes: `assert_difference("Feed.count", 1) { post ... }`
- Verify redirects: `assert_redirected_to feeds_path`

### What controller tests DO NOT

- Test business logic (that goes in command/service tests)
- Test model validations (that goes in model tests)
- Test complex state transitions (that goes in command tests)
- Mock internal service objects (test the full request cycle)

### Conventions

- One `describe` block per action, labeled with HTTP verb: `describe "GET #show"`
- Use `as: :turbo_stream` for Turbo Stream requests
- Use `let` blocks for test data, `before` for authentication
- Nest tests in `test/controllers/` matching the controller directory structure
- For nested controllers: `test/controllers/posts/archives_controller_test.rb`

---

## Quick Reference: Do vs Don't

| Do | Don't |
|---|---|
| Extract `archive` to `Posts::ArchivesController` | Add `def archive` to `PostsController` |
| Define actions in order: index, show, new, edit, create, update, destroy | Put destroy before show or mix the order |
| Add `# GET /posts/:id` above each action | Leave actions undocumented |
| Load `@post` in `before_action :set_post` | Set `@post = ...` inside each action |
| Use the standard 7 actions | Add `def toggle`, `def refresh`, `def duplicate` |
| Keep `@post.discard!` inline (simple) | Extract a one-liner to a service object |
| Use `Posts::Create.run(...)` for multi-step logic | Write 20 lines of create logic in the controller |
| Scope with `current_account.posts.find(id)` | Use `Post.find(id)` without scoping |
| Write controller tests that assert response codes | Test business logic in controller tests |
| Return arrays of turbo streams for multi-update | Use `redirect_to` for everything |
| Keep `pane_preview` on parent (it's still `show`) | Add `pane_archive` as a custom pane action |
| Name controllers as nouns (`ArchivesController`) | Name controllers as verbs (`ArchivingController`) |
