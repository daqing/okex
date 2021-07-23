class OKEX::ApiV5
  def initialize(client)
    @client = client
  end

  def instruments
    client.get("/api/v5/public/instruments")
  end

  def orders
    resp = client.get("/api/v5/account/positions")
    
    if resp['code'].to_i == 0 && resp['data'].size > 0
      return resp['data'].map {|params| OKEX::Order.new(params)}
    end

    []
  end

  def short_swap(instid, amount)
    params = {
      "instId": instid,
      "tdMode": "cross",
      "side": "sell",
      "posSide": "short",
      "ordType": "market",
      "sz": "1"
    }

    client.post("/api/v5/trade/order", params)
  end

  def close_long(instid)
    close_position(instid, "long")
  end

  def close_short(instid)
    close_position(instid, "short")
  end

  private

  attr_reader :client

  def close_position(instid, direction)
    params = {
      "instId": instid,
      "mgnMode": "cross",
      "posSide": direction
    }

    client.post("/api/v5/trade/close-position", params)
  end
end