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
require "../dapps/build_in/hra"

module ::Axentro::Core::Data::Transactions
  def internal_actions_list
    # exclude burn_token as this is used to calculate recipients sum
    DApps::UTXO_ACTIONS.reject(&.==("burn_token")).map { |action| "'#{action}'" }.uniq!.join(",")
  end

  # ------- Definition -------
  def transaction_insert_fields_string
    "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
  end

  # ------- Insert -------
  def transaction_insert_values_array(t : Transaction, transaction_idx : Int32, block_index : Int64) : Array(DB::Any)
    ary = [] of DB::Any
    ary << t.id << transaction_idx << block_index << t.action << t.message << t.token << t.prev_hash << t.timestamp << t.scaled << t.kind.to_s << t.version.to_s
  end

  # ------- Query -------
  def get_all_transactions(block_index : Int64)
    transactions_by_query(
      "select * from transactions " \
      "where block_id = ? " \
      "order by idx asc",
      block_index)
  end

  def get_transactions_for_asset(asset_id : String) : Array(AssetVersion)
    transactions = transactions_by_query("select * from transactions where id in (select transaction_id from assets where asset_id = ? order by version desc)", asset_id)
    transactions.map do |t|
      asset = t.assets.first
      address = t.action == "send_asset" ? t.recipients.map(&.address).first : t.senders.map(&.address).first
      AssetVersion.new(asset_id, t.id, asset.version, t.action, address)
    end
  end

  # ------- API -------
  def total_transactions(transaction_kind : TransactionKind) : Int32
    kind = transaction_kind == TransactionKind::SLOW ? "SLOW" : "FAST"
    @db.query_one("select count(*) from transactions where kind = ?", kind, as: Int32)
  end

  def total_transactions_for_block(block_index : Int64) : Int32
    @db.query_one("select count(*) from transactions where block_id = ?", block_index, as: Int32)
  end

  def total_transactions_for_address(address : String) : Int32
    @db.query_one(
      "select count(*) from transactions " \
      "where id in (select transaction_id from senders " \
      "where address = ? " \
      "union select transaction_id from recipients " \
      "where address = ?) ", address, address, as: Int32)
  end

  def total_transactions_size : Int32
    @db.query_one("select count(*) from transactions", as: Int32)
  end

  def get_paginated_transactions(block_index : Int64, page : Int32, per_page : Int32, direction : String, sort_field : String, actions : Array(String))
    limit = per_page
    offset = Math.max((limit * page) - limit, 0)

    actions = actions.join(",") { |a| "'#{a}'" }
    transactions_by_query(
      "select * from transactions " \
      "where block_id = ? " +
      (actions.empty? ? "" : "and action in (#{actions}) ") +
      "order by #{sort_field} #{direction} " \
      "limit ? offset ?",
      block_index, limit, offset)
  end

  def get_paginated_all_transactions(page : Int32, per_page : Int32, direction : String, sort_field : String, actions : Array(String))
    limit = per_page
    offset = Math.max((limit * page) - limit, 0)

    actions = actions.join(",") { |a| "'#{a}'" }
    transactions_by_query(
      "select * from transactions " +
      (actions.empty? ? "" : "where action in (#{actions}) ") +
      "order by #{sort_field} #{direction} " \
      "limit ? offset ?",
      limit, offset)
  end

  def get_paginated_transactions_for_address(address : String, page : Int32, per_page : Int32, direction : String, sort_field : 