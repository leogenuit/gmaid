class MessagesController < ApplicationController
  def index
    if params[:query].present?
      sql_query = "sender_email ILIKE :query"
      @messages = Message.where(sql_query, query: "%#{params[:query]}%")
    else
      @messages = Message.all
    end
  end

  def show
    @message = Message.find(params[:id])
    @label = Label.new
  end

  def destroy
    @message = Message.destroy(params[:id])
  end

  private

  def big_senders
    query = "SELECT content FROM messages"

    @biggest_senders = ActiveRecord::Base.connection.execute(query).to_a
  end
end
