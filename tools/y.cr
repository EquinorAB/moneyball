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

require "file_utils"

FileUtils.rm_rf("miners")
FileUtils.mkdir("miners")

AMOUNT = 40

(0..AMOUNT).to_a.each do |n|
  puts `axe wallet create -w miners/wallet_#{n}.json --testnet`
end

(0..AMOUNT).to_a.each do |n|
  File.open(