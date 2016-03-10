class Output < ActiveRecord::Base
 belongs_to :owner, :class_name => "User"
 has_and_belongs_to_many :forms
 has_many :output_jobs

 validates :name, :type, presence: true

  def to_s
   self.name
  end
  def run
   raise 'No output run code defined'
  end
end