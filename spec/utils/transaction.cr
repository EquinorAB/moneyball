
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

module ::Units::Utils::TransactionHelper
  include Axentro::Core

  def a_recipient(wallet : Wallet, amount : Int64) : Transaction::Recipient
    Recipient.new(wallet.address, amount)
  end

  def a_recipient(recipient_address : String, amount : Int64) : Transaction::Recipient
    Recipient.new(recipient_address, amount)
  end

  def an_asset_recipient(wallet : Wallet, asset_id : String?, asset_quantity : Int32? = 1, amount : Int64 = 0_i64)