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

module ::Axentro::Core::NodeComponents::Metrics
  # Current connections
  # miners, nodes
  Crometheus.alias ConnectedGauge = Crometheus::Gauge[:kind]
  METRICS_CONNECTED_GAUGE = ConnectedGauge.new(:axnt_connected, "Currently connected (miners, public_nodes, private_nodes)")

  # Miners
  # joined, remove