---
name: fullstack-rails-api
description: >
  How to build RESTful JSON APIs in a Rails 8 application following OpenAPI standards.
  Use when creating, modifying, or debugging API endpoints, serializers, authentication,
  documentation, or any code under the Api:: namespace. Also use when the user mentions
  "api", "endpoint", "api key", "serializer", "openapi", "swagger", "api documentation",
  "cors", "rate limit", "pagination cursor", "api versioning", or asks about exposing
  data to external consumers. Proactively apply these rules whenever touching API
  controllers, routes, or serializers, even if the user doesn't explicitly ask.
---

# Rails API Development

This project exposes a JSON API under the `Api::V1::` namespace for external consumers. All API code follows OpenAPI 3.x standards so that documentation stays accurate, clients can be auto-generated, and the API behaves predictably for third-party integrators.

## Architecture Overview

```
app/
├── controllers/
│   └── api/
│       └── v1/
│           ├── base_controller.rb    # Auth, error handling, pagination
│           ├── bookmarks_controller.rb
│           └── ...
├── serializers/
│   └── api/
│       └── v1/
│           ├── bookmark_serializer.rb
│           └── ...
└── services/                         # Reuse existing service objects
    └── bookmarks/
        ├── create.rb
        └── ...

config/
├── initializers/
│   ├── cors.rb                       # Rack::Cors configuration
│   └── rate_limit.rb                 # Rack::Attack configuration
└── routes.rb                         # API namespace and versioned routes
```

API controllers are a thin interface to existing service objects — they handle authentication, serialization, and HTTP semantics, but delegate business logic to the same services the web app uses. This avoids duplicating logic across two interfaces.

## Versioning

All API endpoints live under a URL-based version prefix. This makes the version visible in every request and easy to reason about for external consumers.

### Routes

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :bookmarks, only: [:index, :show, :create, :update, :destroy]
    resources :collections, only: [:index, :show]
    # Add resources as needed
  end
end
```

This produces routes like `/api/v1/bookmarks`, `/api/v1/bookmarks/:id`, etc.

When introducing a breaking change in the future, create `Api::V2::` alongside V1 rather than modifying V1. Non-breaking additions (new fields, new endpoints) can go into the existing version.

## Base Controller

Every API controller inherits from a base controller that centralizes authentication, error handling, and response helpers.

```ruby
# frozen_string_literal: true

# Base controller for all API V1 endpoints. Handles authentication,
# standard error responses, and shared pagination logic so individual
# controllers stay focused on their resource.
class Api::V1::BaseController < ActionController::API
  before_action :authenticate_api_key

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private

  # Authenticates requests via the X-Api-Key header.
  # API keys are stored on the Account model.
  def authenticate_api_key
    api_key = request.headers["X-Api-Key"]
    @current_account = Account.find_by(api_key: api_key)

    render_error(status: 401, message: "Invalid or missing API key") unless @current_account
  end

  attr_reader :current_account

  # --- Error response helpers ---

  def render_error(status:, message:, details: [])
    render json: {
      error: {
        status: Rack::Utils.status_code(status),
        message: message,
        details: Array(details)
      }
    }, status: status
  end

  def not_found(exception)
    render_error(status: 404, message: "Resource not found")
  end

  def unprocessable_entity(exception)
    render_error(
      status: 422,
      message: "Validation failed",
      details: exception.record.errors.full_messages
    )
  end

  def bad_request(exception)
    render_error(status: 400, message: exception.message)
  end

  # --- Pagination helpers ---

  def paginate(scope, default_limit: 25, max_limit: 100)
    limit = [(params[:limit] || default_limit).to_i, max_limit].min
    after_cursor = params[:after]

    records = if after_cursor
      scope.where("id > ?", decode_cursor(after_cursor))
    else
      scope
    end

    records = records.order(id: :asc).limit(limit + 1).to_a

    has_next = records.size > limit
    records = records.first(limit)

    {
      records: records,
      meta: {
        next_cursor: has_next ? encode_cursor(records.last.id) : nil,
        has_more: has_next,
        limit: limit
      }
    }
  end

  def encode_cursor(id)
    Base64.urlsafe_encode64(id.to_s)
  end

  def decode_cursor(cursor)
    Base64.urlsafe_decode64(cursor).to_i
  rescue ArgumentError
    0
  end
end
```

## Authentication

API consumers authenticate with an API key passed in the `X-Api-Key` header:

```
GET /api/v1/bookmarks
X-Api-Key: sk_live_abc123def456
```

Every request without a valid key receives a `401 Unauthorized` response. The API key maps to an Account, so all queries are automatically scoped to the correct tenant.

### Generating API keys

Store API keys on the Account model. Generate them with `SecureRandom.hex(32)` and prefix them for easy identification (e.g., `sk_live_` for production, `sk_test_` for sandbox).

## Controller Pattern

API controllers follow the same RESTful conventions as web controllers — standard 7 actions only, thin orchestration, delegate to service objects for complex logic.

```ruby
# frozen_string_literal: true

# Exposes bookmarks to external API consumers.
# Delegates business logic to existing service objects.
class Api::V1::BookmarksController < Api::V1::BaseController
  before_action :set_bookmark, only: [:show, :update, :destroy]

  # GET /api/v1/bookmarks
  def index
    result = paginate(current_account.bookmarks)

    render json: {
      data: Api::V1::BookmarkSerializer.new(result[:records]).as_json,
      meta: result[:meta]
    }
  end

  # GET /api/v1/bookmarks/:id
  def show
    render json: { data: Api::V1::BookmarkSerializer.new(@bookmark).as_json }
  end

  # POST /api/v1/bookmarks
  def create
    result = Bookmarks::Create.call(
      params: bookmark_params,
      account: current_account
    )

    if result.success?
      render json: { data: Api::V1::BookmarkSerializer.new(result.bookmark).as_json },
             status: :created
    else
      render_error(status: 422, message: "Validation failed", details: result.errors.message_list)
    end
  end

  # PATCH /api/v1/bookmarks/:id
  def update
    result = Bookmarks::Update.run(
      bookmark: @bookmark,
      params: bookmark_params.to_h
    )

    if result.success?
      render json: { data: Api::V1::BookmarkSerializer.new(@bookmark.reload).as_json }
    else
      render_error(status: 422, message: "Validation failed", details: result.errors.message_list)
    end
  end

  # DELETE /api/v1/bookmarks/:id
  def destroy
    @bookmark.discard!
    head :no_content
  end

  private

  def set_bookmark
    @bookmark = current_account.bookmarks.find(params[:id])
  end

  def bookmark_params
    params.require(:bookmark).permit(:title, :url, :description, :collection_id)
  end
end
```

Key points:
- Always scope queries through `current_account` — never use unscoped `Bookmark.find`
- Reuse existing service objects (`Bookmarks::Create`, `Bookmarks::Update`, etc.)
- Return `201 Created` for successful creation, `204 No Content` for deletion
- Wrap response data in a `data` key for consistency

## Serialization

Use a serializer gem (alba or blueprinter) to control exactly which fields are exposed. Never return raw `ActiveRecord` objects — external consumers should see a stable, documented contract.

```ruby
# frozen_string_literal: true

# Serializes bookmarks for the V1 API. Controls which fields
# are visible to external consumers — adding fields here is a
# public contract change.
class Api::V1::BookmarkSerializer
  attr_reader :resource

  def initialize(resource)
    @resource = resource
  end

  def as_json
    if resource.respond_to?(:map)
      resource.map { |record| serialize(record) }
    else
      serialize(resource)
    end
  end

  private

  def serialize(record)
    {
      id: record.id,
      title: record.title,
      url: record.url,
      description: record.description,
      host: record.host,
      created_at: record.created_at.iso8601,
      updated_at: record.updated_at.iso8601
    }
  end
end
```

Guidelines:
- Always use `iso8601` for timestamps — external consumers need a predictable format
- Only expose fields that external consumers need — not internal columns like `discarded_at` or `embedding_vector`
- When adding a new field, consider it a public contract — removing it later is a breaking change
- Nest related resources under a key (e.g., `collection: { id: 1, title: "..." }`) rather than flattening

## Response Format

All successful responses wrap data in a `data` key. List endpoints also include a `meta` key for pagination.

### Single resource

```json
{
  "data": {
    "id": 1,
    "title": "Example Bookmark",
    "url": "https://example.com",
    "created_at": "2026-03-18T12:00:00Z",
    "updated_at": "2026-03-18T12:00:00Z"
  }
}
```

### Collection with pagination

```json
{
  "data": [
    { "id": 1, "title": "First" },
    { "id": 2, "title": "Second" }
  ],
  "meta": {
    "next_cursor": "MjU",
    "has_more": true,
    "limit": 25
  }
}
```

### Error

```json
{
  "error": {
    "status": 422,
    "message": "Validation failed",
    "details": ["Title can't be blank", "URL is not valid"]
  }
}
```

## Pagination

Use cursor-based pagination for all list endpoints. Cursor-based pagination performs better than page/offset for large datasets because it doesn't degrade as the offset grows, and it handles records being added or removed between requests.

Clients pass two parameters:
- `limit` — how many records to return (default 25, max 100)
- `after` — cursor from a previous response's `meta.next_cursor`

```
GET /api/v1/bookmarks?limit=10
GET /api/v1/bookmarks?limit=10&after=MjU
```

The base controller's `paginate` helper handles this. See the base controller section above for the implementation.

## Rate Limiting

Use `rack-attack` to protect API endpoints from abuse. Return standard rate limit headers so consumers can self-throttle.

```ruby
# config/initializers/rate_limit.rb

Rack::Attack.throttle("api/v1", limit: 100, period: 60) do |req|
  if req.path.start_with?("/api/v1")
    req.env["HTTP_X_API_KEY"]
  end
end

Rack::Attack.throttled_responder = lambda do |_env|
  now = Time.current
  match_data = _env["rack.attack.match_data"]

  headers = {
    "Content-Type" => "application/json",
    "X-RateLimit-Limit" => match_data[:limit].to_s,
    "X-RateLimit-Remaining" => "0",
    "X-RateLimit-Reset" => (now + (match_data[:period] - now.to_i % match_data[:period])).iso8601
  }

  body = {
    error: {
      status: 429,
      message: "Rate limit exceeded. Try again later.",
      details: []
    }
  }

  [429, headers, [body.to_json]]
end
```

Include rate limit headers on every response via a `before_action` or middleware so consumers always know their remaining quota.

## CORS

Configure `rack-cors` to allow external consumers to call the API from browser-based clients.

```ruby
# config/initializers/cors.rb

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*" # Restrict to specific domains in production

    resource "/api/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ["X-RateLimit-Limit", "X-RateLimit-Remaining", "X-RateLimit-Reset"],
      max_age: 600
  end
end
```

In production, replace `origins "*"` with specific allowed domains. Expose rate limit headers so browser-based consumers can read them.

## OpenAPI Documentation

Generate the OpenAPI spec from your controllers using `rswag`. This keeps documentation in sync with actual API behavior — when tests pass, the spec is accurate.

### Setup

Add to `Gemfile`:

```ruby
gem "rswag-api"
gem "rswag-ui"
gem "rswag-specs", group: [:test]
```

### Writing spec-driven documentation

```ruby
# spec/requests/api/v1/bookmarks_spec.rb (or test equivalent)

require "swagger_helper"

RSpec.describe "Api::V1::Bookmarks", type: :request do
  path "/api/v1/bookmarks" do
    get "List bookmarks" do
      tags "Bookmarks"
      produces "application/json"
      security [api_key: []]

      parameter name: :limit, in: :query, type: :integer, required: false,
                description: "Number of records to return (max 100)"
      parameter name: :after, in: :query, type: :string, required: false,
                description: "Cursor for the next page of results"

      response "200", "Bookmarks retrieved" do
        schema type: :object,
          properties: {
            data: {
              type: :array,
              items: { "$ref" => "#/components/schemas/Bookmark" }
            },
            meta: { "$ref" => "#/components/schemas/PaginationMeta" }
          }

        run_test!
      end

      response "401", "Unauthorized" do
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end

    post "Create a bookmark" do
      tags "Bookmarks"
      consumes "application/json"
      produces "application/json"
      security [api_key: []]

      parameter name: :bookmark, in: :body, schema: {
        type: :object,
        properties: {
          bookmark: {
            type: :object,
            properties: {
              title: { type: :string },
              url: { type: :string, format: :uri },
              description: { type: :string },
              collection_id: { type: :integer }
            },
            required: ["url"]
          }
        }
      }

      response "201", "Bookmark created" do
        schema type: :object,
          properties: {
            data: { "$ref" => "#/components/schemas/Bookmark" }
          }

        run_test!
      end

      response "422", "Validation failed" do
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end
  end
end
```

### Generating the spec

```bash
rails rswag:specs:swaggerize
```

This outputs `swagger/v1/swagger.yaml` which can be served at `/api-docs`.

### Defining reusable schemas

```yaml
# swagger/v1/swagger.yaml (components section)
components:
  schemas:
    Bookmark:
      type: object
      properties:
        id:
          type: integer
        title:
          type: string
        url:
          type: string
          format: uri
        description:
          type: string
          nullable: true
        host:
          type: string
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time

    PaginationMeta:
      type: object
      properties:
        next_cursor:
          type: string
          nullable: true
        has_more:
          type: boolean
        limit:
          type: integer

    Error:
      type: object
      properties:
        error:
          type: object
          properties:
            status:
              type: integer
            message:
              type: string
            details:
              type: array
              items:
                type: string

  securitySchemes:
    api_key:
      type: apiKey
      name: X-Api-Key
      in: header
```

## HTTP Status Codes

Use these consistently across all endpoints:

| Status | When |
|--------|------|
| `200 OK` | Successful GET, PATCH |
| `201 Created` | Successful POST |
| `204 No Content` | Successful DELETE |
| `400 Bad Request` | Malformed request or missing required params |
| `401 Unauthorized` | Missing or invalid API key |
| `404 Not Found` | Resource doesn't exist or isn't accessible |
| `422 Unprocessable Entity` | Validation failures |
| `429 Too Many Requests` | Rate limit exceeded |
| `500 Internal Server Error` | Unexpected server error |

## Checklist for New API Endpoints

1. **Add route** under `namespace :api / namespace :v1` in `config/routes.rb`
2. **Create controller** inheriting from `Api::V1::BaseController`
3. **Reuse existing service objects** — don't duplicate business logic
4. **Create a serializer** in `app/serializers/api/v1/` — only expose fields consumers need
5. **Scope all queries** through `current_account`
6. **Write request specs** with rswag to generate OpenAPI documentation
7. **Regenerate the OpenAPI spec** with `rails rswag:specs:swaggerize`
8. **Test error cases** — 401, 404, 422 responses
9. **Verify cursor pagination** works for list endpoints
10. **Check CORS** if the endpoint will be called from browsers
