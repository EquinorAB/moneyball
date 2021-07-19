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
require "../blockchain/*"
require "../blockchain/domain_model/*"

module ::Axentro::Core::Data::Senders
  # ------- Definition -------

  def sender_insert_fields_string
    "?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
  end

  # ------- Insert -------
  def sender_insert_values_array(b : Block, t : Transaction, sender_index : Int32) : Array(DB::Any)
    ary = [] of DB::Any
    s = t.senders[sender_index]
    ary << t.id << b.index << sender_index << s.address << s.public_key << s.amount << s.fee << s.signature << s.asset_id << s