class Note < ActiveRecord::Base
  belongs_to :notable, :polymorphic => true
end