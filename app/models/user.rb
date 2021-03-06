class User < ActiveRecord::Base
  has_many :forms
  has_many :outputs
  has_many :identities, :dependent => :delete_all

  # Define what an email should look like
  TEMP_EMAIL_PREFIX = 'change@me'
  TEMP_EMAIL_REGEX = /\Achange@me/

  # Include default devise modules. Others available are:
  #  :lockable, :timeoutable, :confirmable
  devise :database_authenticatable, :registerable, :omniauthable,
         :recoverable, :rememberable, :trackable, :validatable, :omniauth_providers => [:google]

  def self.find_for_oauth(auth, signed_in_resource = nil)
    # Get the identity and user if they exist
    identity = Identity.find_for_oauth(auth)

    # If a signed_in_resource is provided it always overrides the existing user
    # to prevent the identity being locked with accidentally created accounts.
    # Note that this may leave zombie accounts (with no associated identity) which
    # can be cleaned up at a later date.
    user = signed_in_resource ? signed_in_resource : identity.user

    # Create the user if needed
    if user.nil?

      # Get the existing user by email if the provider (eg. facebook) gives us a verified email.
      # If no verified email was provided we assign a temporary email and ask the
      # user to verify it on the next step via UsersController.finish_signup
      # https://stackoverflow.com/questions/27085336/when-using-omniauth-in-rails-google-omniauth2-creates-a-new-user-if-the-user-ex
      if auth.provider == 'google'
        email = auth.info.email
      else
        email_is_verified = auth.info.email && (auth.info.verified || auth.info.verified_email)
        email = auth.info.email if email_is_verified
      end
      user = User.where(:email => email).first if email

      # Create the user if it's a new registration
      if user.nil?
        user = User.new(
            name: auth.extra.raw_info.name,
            #username: auth.info.nickname || auth.uid,
            email: email ? email : "#{TEMP_EMAIL_PREFIX}-#{auth.uid}-#{auth.provider}.com",
            password: Devise.friendly_token[0, 20],
            approved: (auth.provider == 'google'),
            admin: (email == 'alex.sadleir@digital.gov.au')
        )
        #user.skip_confirmation!
        user.save!
      end
    end

    # Associate the identity with the user if needed
    @auth = auth['credentials']
    if identity.user != user or not @auth['refresh_token'].nil?
      identity.access_token = @auth['token']
      identity.id_token = auth['extra']['id_token']
      identity.refresh_token = @auth['refresh_token']
      identity.expires_at = Time.at(@auth['expires_at']).to_datetime
      identity.user = user
      identity.save!
    end
    if identity.refresh_token.nil?
      set_flash_message(:error, "You logged in via Google but the API setup did not complete. go to https://security.google.com/settings/security/permissions and revoke this app's access")
    end
    user
  end

  def email_verified?
    self.email && self.email !~ TEMP_EMAIL_REGEX
  end

  def is_admin?
    self.admin
  end

  def active_for_authentication?
    super && approved?
  end

  def inactive_message
    if !approved?
      :not_approved
    else
      super # Use whatever other message
    end
  end
  protected
end
