# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::CommentsController do
  render_views

  describe "#update" do
    let(:event) { create(:event) }
    let(:hcb_code) { create(:disbursement, source_event: event).outgoing_disbursement.local_hcb_code }
    let(:comment) { create(:comment, commentable: hcb_code, user:, content: "Original content", admin_only: false) }

    def authenticate_as(user, scopes: nil)
      token = create(:api_token, user:, scopes:)
      request.headers["Authorization"] = "Bearer #{token.token}"
    end

    def update_comment(params)
      patch :update, params: { id: comment.public_id, **params }, as: :json
    end

    context "as an auditor" do
      let(:user) { create(:user, :make_auditor) }

      before { authenticate_as(user, scopes: "admin:read") }

      it "updates the content" do
        update_comment(content: "Edited content")

        expect(response).to have_http_status(:ok)
        expect(comment.reload.content).to eq("Edited content")
        expect(response.parsed_body).to include("content" => "Edited content")
      end

      context "when admin_only is omitted" do
        it "leaves a public comment public" do
          expect { update_comment(content: "Edited content") }.not_to(change { comment.reload.admin_only }.from(false))

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).not_to have_key("admin_only")
        end

        it "leaves an admin-only comment admin-only" do
          comment.update!(admin_only: true)

          expect { update_comment(content: "Edited content") }.not_to(change { comment.reload.admin_only }.from(true))

          expect(response).to have_http_status(:ok)
          expect(comment.reload.content).to eq("Edited content")
          expect(response.parsed_body).to include("admin_only" => true)
        end
      end

      context "when admin_only is a boolean" do
        it "marks a public comment as admin-only, leaving the content alone" do
          expect { update_comment(admin_only: true) }.to change { comment.reload.admin_only }.from(false).to(true)

          expect(response).to have_http_status(:ok)
          expect(comment.reload.content).to eq("Original content")
          expect(response.parsed_body).to include("admin_only" => true, "content" => "Original content")
        end

        it "marks an admin-only comment as public" do
          comment.update!(admin_only: true)

          expect { update_comment(admin_only: false) }.to change { comment.reload.admin_only }.from(true).to(false)

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).not_to have_key("admin_only")
        end
      end

      context "when admin_only is not a boolean" do
        {
          "true"   => true,
          "false"  => false,
          "t"      => true,
          "f"      => false,
          "0"      => false,
          "1"      => true,
          0        => false,
          1        => true,
          2        => true,
          "yes"    => true,
          "banana" => true,
        }.each do |value, expected|
          it "casts #{value.inspect} to #{expected}" do
            update_comment(admin_only: value)

            expect(response).to have_http_status(:ok)
            expect(comment.reload.admin_only).to eq(expected)
          end
        end

        it "rejects a value that casts to nil" do
          comment.update!(admin_only: true)

          expect { update_comment(admin_only: "") }.not_to(change { comment.reload.admin_only }.from(true))

          expect(response).to have_http_status(:internal_server_error)
          expect(response.parsed_body).to eq(
            {
              "error"    => "internal_error",
              "messages" => ["Internal database error"]
            }
          )
        end
      end
    end

    context "as an organizer who is not an auditor" do
      let(:user) { create(:user) }

      before do
        create(:organizer_position, user:, event:)
        authenticate_as(user)
      end

      it "edits the content of its own public comment" do
        update_comment(content: "Edited content")

        expect(response).to have_http_status(:ok)
        expect(comment.reload.content).to eq("Edited content")
      end

      it "leaves admin_only alone when it is omitted" do
        expect { update_comment(content: "Edited content") }.not_to(change { comment.reload.admin_only }.from(false))

        expect(response).to have_http_status(:ok)
      end

      it "cannot make its own comment admin-only" do
        expect { update_comment(admin_only: true) }.not_to(change { comment.reload.admin_only }.from(false))

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body).to eq({ "error" => "not_authorized" })
      end

      ["true", "t", "1", 1, 2, "yes", "banana"].each do |value|
        it "cannot make its own comment admin-only with #{value.inspect}" do
          expect { update_comment(admin_only: value) }.not_to(change { comment.reload.admin_only }.from(false))

          expect(response).to have_http_status(:forbidden)
        end
      end

      it "cannot edit a comment that is already admin-only" do
        comment.update!(admin_only: true)

        expect { update_comment(content: "Edited content") }.not_to(change { comment.reload.attributes })

        expect(response).to have_http_status(:forbidden)
      end

      it "cannot make an admin-only comment public" do
        comment.update!(admin_only: true)

        expect { update_comment(admin_only: false) }.not_to(change { comment.reload.admin_only }.from(true))

        expect(response).to have_http_status(:forbidden)
      end

      it "ignores a non-scalar admin_only value" do
        expect { update_comment(admin_only: { hacked: true }) }.not_to(change { comment.reload.admin_only }.from(false))

        expect(response).to have_http_status(:ok)
      end

      it "may still set admin_only to a falsy value" do
        expect { update_comment(admin_only: "false") }.not_to(change { comment.reload.admin_only }.from(false))

        expect(response).to have_http_status(:ok)
      end
    end

    context "when a file is passed" do
      let(:user) { create(:user) }

      before do
        create(:organizer_position, user:, event:)
        authenticate_as(user)
      end

      it "is ignored" do
        patch :update, params: {
          id: comment.public_id,
          content: "Edited content",
          file: fixture_file_upload("attachment1.txt", "text/plain")
        }, format: :json

        expect(response).to have_http_status(:ok)
        expect(comment.reload.content).to eq("Edited content")
        expect(comment.file).not_to be_attached
      end
    end

    context "when the comment belongs to someone else" do
      let(:user) { create(:user) }

      before do
        create(:organizer_position, user:, event:)

        other_user = create(:user)
        create(:organizer_position, user: other_user, event:)
        authenticate_as(other_user)
      end

      it "is forbidden" do
        expect { update_comment(content: "Edited content", admin_only: true) }.not_to(change { comment.reload.attributes })

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body).to eq({ "error" => "not_authorized" })
      end
    end
  end
end