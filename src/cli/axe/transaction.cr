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

module ::Axentro::Interface::Axe
  class Transaction < CLI
    def sub_actions : Array(AxeAction)
      [
        {
          name: I18n.translate("axe.cli.transaction.create.title"),
          desc: I18n.translate("axe.cli.transaction.create.desc"),
        },
        {
          name: I18n.translate("axe.cli.transaction.transactions.title"),
          desc: I18n.translate("axe.cli.transaction.transactions.desc"),
        },
        {
          name: I18n.translate("axe.cli.transaction.transaction.title"),
          desc: I18n.translate("axe.cli.transaction.transaction.desc"),
        },
        {
          name: I18n.translate("axe.cli.transaction.fees.title"),
          desc: I18n.translate("axe.cli.transaction.fees.desc"),
        },
      ]
    end

    def option_parser : OptionParser?
      G.op.create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::JSON,
        Options::ADDRESS,
        Options::AMOUNT,
        Options::ACTION,
        Options::MESSAGE,
        Options::BLOCK_INDEX,
        Options::TRANSACTION_ID,
        Options::FEE,
        Options::DOMAIN,
        Options::TOKEN,
        Options::CONFIG_NAME,
        Options::IS_FAST_TRANSACTION,
      ])
    end

    def run_impl(action_name) : OptionParser?
      case action_name
      when I18n.translate("axe.cli.transaction.c