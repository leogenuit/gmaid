class MessagesController < ApplicationController
  def index
    select_query = <<~SQL
      messages.*,
      (regexp_matches (messages.from, '(.+)\s<(.+)@(.+)>'))[1] as name,
      (regexp_matches (messages.from, '(.+)\s<(.+)@(.+)>'))[2] as sender,
      (regexp_matches (messages.from, '(.+)\s<(.+)@(.+)>'))[3] as sender_domain
    SQL
    @messages = Message.select(select_query)
    if params[:sender_domain].present?
      @messages = @messages.where("messages.from ILIKE ?", "%#{params[:sender_domain]}%")
    end


    @data = @messages.group_by do |m|
      m.sender_domain
    end.transform_values! do |messages|
      messages.group_by do |m|
        m.sender
      end.transform_values! do |messages|
        messages.group_by do |m|
          m.name
        end
      end
    end
  end

  def show
    @message = Message.find(params[:id])
    @label = Label.new
  end

  def destroy
    @message = Message.destroy(params[:id])
  end

  def batch_action
    case params[:commit]
    when "Mark as read" then batch_mark_as_read
    when "Delete" then batch_delete
    else
      puts "no commit ..."
    end

    redirect_to request.referrer

  end

  def sync
    # current_user.messages.destroy_all
    SyncMessages.new(current_user).call
    redirect_to root_path
  end

  private

  def batch_mark_as_read
    ap "je suis dans batch_mark_as_read"
    ap params[:ids]

    messages = Message.where(id: params[:ids])
    google_message_ids = messages.pluck(:google_id)
    BatchMarkGoogleMessages.new(User.last, google_message_ids).call

    messages.each do |message|
      LabelsSync.new(message).call
    end
  end

  def batch_delete
    ap "je suis dans batch_delete"
    ap params[:ids]

    messages = Message.where(id: params[:ids])
    google_message_ids = messages.pluck(:google_id)
    BatchTrashGoogleMessages.new(User.last, google_message_ids).call
    messages.destroy_all
  end

  def big_senders
    query = "SELECT snippet FROM messages"

    @biggest_senders = ActiveRecord::Base.connection.execute(query).to_a
  end

end
