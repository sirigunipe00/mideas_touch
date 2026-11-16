// Creates a Razorpay order for a coin pack and records it in payment_orders.
// Secrets: RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const razorpayKeyId = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
    const razorpayKeySecret = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!razorpayKeyId || !razorpayKeySecret) {
      return json({ error: "Razorpay is not configured" }, 500);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json({ error: "Sign in required" }, 401);
    }
    const jwt = authHeader.slice("Bearer ".length);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });
    const {
      data: { user },
      error: userError,
    } = await admin.auth.getUser(jwt);
    if (userError || !user) {
      return json({ error: "Sign in required" }, 401);
    }

    const body = await req.json();
    const packId = Number(body.pack_id);
    if (!Number.isFinite(packId) || packId <= 0) {
      return json({ error: "Invalid pack" }, 400);
    }

    const { data: pack, error: packError } = await admin
      .from("coin_packs")
      .select("id,name,price_inr,coins,bonus_coins,is_active")
      .eq("id", packId)
      .eq("is_active", true)
      .maybeSingle();

    if (packError || !pack) {
      return json({ error: "Invalid pack" }, 400);
    }

    const amountPaise = pack.price_inr * 100;
    const receipt = `pack_${pack.id}_${Date.now()}`.slice(0, 40);

    const orderRes = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${razorpayKeyId}:${razorpayKeySecret}`)}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount: amountPaise,
        currency: "INR",
        receipt,
        notes: {
          pack_id: String(pack.id),
          user_id: user.id,
        },
      }),
    });

    const orderJson = await orderRes.json();
    if (!orderRes.ok) {
      console.error("razorpay order error", orderJson);
      return json({ error: "Could not start payment" }, 502);
    }

    const { error: insertError } = await admin.from("payment_orders").insert({
      user_id: user.id,
      pack_id: pack.id,
      amount_paise: amountPaise,
      currency: "INR",
      razorpay_order_id: orderJson.id,
      status: "pending",
    });

    if (insertError) {
      console.error("payment_orders insert", insertError);
      return json({ error: "Could not save order" }, 500);
    }

    return json({
      orderId: orderJson.id,
      amount: amountPaise,
      currency: "INR",
      keyId: razorpayKeyId,
      packName: pack.name,
    });
  } catch (e) {
    console.error(e);
    return json({ error: "Unexpected error" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
