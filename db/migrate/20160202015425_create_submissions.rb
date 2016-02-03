
class CreateSubmissions < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE extension IF NOT EXISTS pgcrypto;
    SQL
  end
  def change
    create_table :submissions, id: :uuid, default: 'gen_random_uuid()' do |t|
      t.timestamps
      t.string 'path'
      t.decimal 'satisfaction', precision: 3, scale: 0
      t.binary 'file'
      t.string 'file_type'
      t.jsonb 'content'
      t.belongs_to :form, type: :uuid, index: true
    end
  end
end
