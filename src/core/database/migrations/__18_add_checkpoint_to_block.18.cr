
# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

@[MG::Tags("main")]
class AddCheckpointToBlock < MG::Base
  include Axentro::Core
  include Data

  def up : String
    <<-SQL
      ALTER TABLE blocks ADD COLUMN checkpoint TEXT NOT NULL DEFAULT "";
      ALTER TABLE archived_blocks ADD COLUMN checkpoint TEXT NOT NULL DEFAULT "";
    SQL
  end

  def down : String
    ""
  end
end