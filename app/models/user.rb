class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :rememberable, :validatable
  
  has_many :file_uploads, dependent: :destroy
  has_many :api_keys, dependent: :destroy
end
