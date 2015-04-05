class User < ActiveRecord::Base
  attr_accessor :remember_token, :activation_token, :reset_token
  before_save :downcase_email
  before_create :create_activation_digest
  validates :name, presence: true, length: { maximum: 50 }
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :email, presence: true, length: { maximum: 255 },
                    format: { with: VALID_EMAIL_REGEX },
                    uniqueness: { case_sensitive: false }
  has_secure_password
  validates :password, length: { minimum: 6 }, allow_blank: true
  has_many :microposts, dependent: :destroy
  has_many :active_relationships, class_name: "Relationship",
                                  foreign_key: "follower_id",
                                  dependent: :destroy
  has_many :passive_relationships, class_name: "Relationship",
                                  foreign_key: "followed_id",
                                  dependent: :destroy
  has_many :following, through: :active_relationships, source: :followed
  has_many :followers, through: :passive_relationships, source: :follower

  # Hashes string with BCrypt hashing function
  def User.digest(string)
    cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST :
                                                  BCrypt::Engine.cost
    BCrypt::Password.create(string, cost: cost)
  end

  # Generates new random string token
  def User.new_token
    SecureRandom.urlsafe_base64
  end
  
  # Creates remember_token and updates remember_digest attribute
  def remember
    self.remember_token = User.new_token
    update_attribute(:remember_digest, User.digest(remember_token))
  end
    
  # Authenticates token by comparing its hash to the stored digest
  # @param attribute string is either 'remember' or 'activation'
  # @param token string is the string token to be hashed and compared
  def authenticated?(attribute, token)
    digest = self.send("#{attribute}_digest")
    return false if digest.nil?
    BCrypt::Password.new(digest).is_password?(token)
  end
  
  def forget
    update_attribute(:remember_digest, nil)
  end
  
  # Activates an account.
  def activate
    # self is optional inside the model
    update_attribute(:activated,    true)
    update_attribute(:activated_at, Time.zone.now)
  end
  
  # Sends activation email.
  def send_activation_email
    UserMailer.account_activation(self).deliver_now
  end
  
  # Sets the password reset attributes
  def create_reset_digest
    self.reset_token = User.new_token
    update_attribute(:reset_digest, User.digest(reset_token))
    update_attribute(:reset_sent_at, Time.zone.now)
  end
  
  # Sends reset password email.
  def send_password_reset_email
    UserMailer.password_reset(self).deliver_now
  end
  
  # Returns true if password reset has expired.
  def password_reset_expired?
    reset_sent_at < 2.hours.ago
  end
  
  # Defines a proto-feed.
  # TODO: generalize to feeds from followed users
  def feed
    # following_ids provided by Active Record to be same as
    # following.map(&:id)
    # ? string interpolation automatically converts array of following ids
    # to a comma separated string
    # Micropost.where("user_id IN (?) or user_id = ?", following_ids, id)
    # However, this could potentially create an unwieldy SQL query if the number
    # of followers is high.
    # Instead, will use a subquery to find following ids.
    following_ids = "SELECT followed_id FROM relationships
                     WHERE  follower_id = :user_id"
    Micropost.where("user_id IN (#{following_ids})
                     OR user_id = :user_id", user_id: id)
  end
  
  # Follows another user.
  def follow(other_user)
    active_relationships.create(followed_id: other_user.id)
  end
  
  # Unfollows another user.
  def unfollow(other_user)
    active_relationships.find_by(followed_id: other_user.id).destroy
  end
  
  # Returns true if the current user is following the other user.
  def following?(other_user)
    following.include?(other_user)
  end
  
  private
  
    # Converts email to all lower-case
    def downcase_email
      self.email = email.downcase
    end
    
    # Creates and assigns the activation token and digest
    def create_activation_digest
      self.activation_token = User.new_token
      # User automatically gets updated with attributes because this is before
      # creation.
      self.activation_digest = User.digest(self.activation_token)
    end
  
end
