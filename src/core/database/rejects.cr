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
require "../node/*"
require "../dapps/dapp"
require "../dapps/build_in/rejects"

module ::Axentro::Core::Data::Rejects
  # ------- Insert -------
  def insert_reject(reject : Reject)
    @db.exec("insert or ignore into rejects values (?, ?, ?, ?)", reject.transaction_id, reject.sender_address, reject.reason, reject.timestamp)
  end

  # ------- Query -------
  def find_reject(transaction_id : String) : Reject?
    rejects = [] 