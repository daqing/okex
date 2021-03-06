class OKEX::ApiV5
  def initialize(client, host)
    @client = client
    @host = host
  end

  def instruments
    client.get(host, "/api/v5/public/instruments?instType=SWAP")
  end

  def orders(inst_id=nil)
    url = "/api/v5/account/positions"
    if inst_id.present?
      url += "?instId=#{inst_id}"
    end

    data = client.get(host, url)

    data.map {|params| OKEX::Order.new(params)}
  end

  def balance(ccy, round)
    data = client.get(host, "/api/v5/account/balance?ccy=#{ccy}")

    details = data[0]['details'][0]

    OKEX::Balance.new(
      details['ccy'],
      dig_round(details, 'cashBal', round),
      dig_round(details, 'avalEq', round),
      dig_round(details, 'frozenBal', round),
      dig_round(details, 'upl', round)
    )
  end

  def long_swap(instid, amount)
    params = {
      "instId": instid,
      "tdMode": "cross",
      "side": "buy",
      "posSide": "long",
      "ordType": "market",
      "sz": amount.to_s,
    }

    client.post(host, "/api/v5/trade/order", params)
  end

  def short_swap(instid, amount)
    params = {
      "instId": instid,
      "tdMode": "cross",
      "side": "sell",
      "posSide": "short",
      "ordType": "market",
      "sz": amount.to_s,
    }

    client.post(host, "/api/v5/trade/order", params)
  end

  def close_long(instrument_id)
    close_position(instrument_id, "long")
  end

  def close_short(instrument_id)
    close_position(instrument_id, "short")
  end

  def max_size(instrument_id)
    data = client.get(host, "/api/v5/account/max-size?instId=#{instrument_id}&tdMode=cross")

    ret = OKEX::MaxSize.new(-1, -1)

    el = data[0]
    if el.present? && el['maxBuy'].to_i > 0 && el['maxSell'].to_i > 0
      ret = OKEX::MaxSize.new(el['maxBuy'].to_i, el['maxSell'].to_i)
    end

    ret
  end

  def current_leverage(inst_id)
    data = client.get(host, "/api/v5/account/leverage-info?instId=#{inst_id}&mgnMode=cross")

    data[0]['lever'].to_i
  end

  # 设置止损价格
  # @param inst_id [String] 合约名称
  # @param posSide [String] 持仓方向
  # @param sz [Integer] 持仓数量（张）
  # @param price [Float] 止损价格
  def set_stop_loss(inst_id, posSide, sz, price)
    side = (posSide == OKEX::Order::POS_LONG) ? "sell" : "buy"

    params = {
      "instId": inst_id,
      "tdMode": "cross",
      "side": side,
      "posSide": posSide.to_s,
      "sz": sz.to_s,
      "ordType": "conditional",
      "slTriggerPx": price.to_s,
      "slOrdPx": "-1"
    }

    client.post(host, "/api/v5/trade/order-algo", params)
  end

  # 查询当前设置的止损价格
  # @param inst_id [String] 合约名称
  def stop_loss_price(inst_id)
    result = client.get(host, "/api/v5/trade/orders-algo-pending?instId=#{inst_id}&instType=SWAP&ordType=conditional")

    return -1 if result.empty?
    return result[0]["slTriggerPx"].to_f if result.size == 1

    raise "invalid result: #{result.inspect}"
  end

  # 查询当前止损订单的ID
  # 可用于后续取消止损订单
  # @param inst_id [String] 合约名称
  def algo_order_id(inst_id)
    result = client.get(host, "/api/v5/trade/orders-algo-pending?instId=#{inst_id}&instType=SWAP&ordType=conditional")

    return "" if result.empty?
    return result[0]["algoId"] if result.size == 1

    raise "invalid result: #{result.inspect}"
  end

  # 撤销委托单
  # @param algo_id [String] 策略委托单ID
  # @param inst_id [String] 合约ID
  def cancel_algo_order(algo_id, inst_id)
    params = {
      "algoId": algo_id,
      "instId": inst_id
    }

    client.post(host, "/api/v5/trade/cancel-algos", [params])
  end

  private

  attr_reader :client, :host

  def close_position(instrument_id, direction)
    params = {
      "instId": instrument_id,
      "mgnMode": "cross",
      "posSide": direction
    }

    client.post(host, "/api/v5/trade/close-position", params)
  end

  def dig_round(obj, key, round)
    obj[key].to_f.round(round)
  end
end
