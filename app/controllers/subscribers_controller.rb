class SubscribersController < ApplicationController
  # Public sign-up for the lunar newsletter, with double opt-in confirmation
  # and tokenized unsubscribe.

  def new
    @user = User.new
  end

  def thanks
  end

  def create
    # Honeypot: real users never fill this hidden field; bots do.
    return redirect_to(subscriber_thanks_path, status: :see_other) if params[:nickname].present?

    email = params.dig(:user, :email).to_s.strip.downcase
    @user = User.find_or_initialize_by(email: email)

    # Already an active subscriber → neutral response (no email enumeration).
    if @user.persisted? && @user.confirmed? && !@user.unsubscribed?
      return redirect_to(subscriber_thanks_path, status: :see_other)
    end

    @user.name = params.dig(:user, :name).presence if @user.new_record?

    # Coordinates from the browser's geolocation (optional) → fall back to any
    # existing value, then to the default location.
    @user.latitude = params.dig(:user, :latitude).presence || @user.latitude || User::DEFAULT_LATITUDE
    @user.longitude = params.dig(:user, :longitude).presence || @user.longitude || User::DEFAULT_LONGITUDE

    # Re-subscribing or still unconfirmed: (re)send the confirmation.
    @user.unsubscribed_at = nil

    if @user.save
      deliver_confirmation(@user)
      redirect_to subscriber_thanks_path, status: :see_other
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def confirm
    user = User.find_by(confirmation_token: params[:token])
    @title = "Inscrição confirmada 🌙"
    @message =
      if user
        user.confirm!
        "Pronto, #{user.name.presence || 'explorador lunar'}! Você receberá o boletim lunar a cada fase principal."
      else
        @title = "Link inválido"
        "Este link de confirmação é inválido ou já foi usado."
      end
    render :message
  end

  def unsubscribe
    user = User.find_by(unsubscribe_token: params[:token])
    user&.unsubscribe!
    @title = "Inscrição cancelada"
    @message = "Você foi removido da lista e não receberá mais o boletim lunar. Sentiremos sua falta!"
    render :message
  end

  private

  # A signup must never 500 because the mail backend rejected/failed the send
  # (e.g. SES sandbox refusing an unverified recipient). Log it and move on —
  # the user row exists and can be confirmed once delivery is sorted.
  def deliver_confirmation(user)
    SubscriptionMailer.confirmation(user).deliver_now
  rescue => e
    Rails.logger.error("SubscribersController: confirmation email failed for #{user.email}: #{e.class}: #{e.message}")
  end
end
