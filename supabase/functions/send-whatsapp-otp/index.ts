/// <reference lib="deno.ns" />
import { serve } from "https://deno.land/std@0.177.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface WhatsAppPayload {
  user?: {
    id?: string;
    phone?: string;
  };
  sms?: {
    otp?: string;
  };
  phone?: string;
  otp?: string;
  template_name?: string;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const payload: WhatsAppPayload = await req.json().catch(() => ({}))

    // Support both Supabase Auth Hook payload and direct API invocation
    const rawPhone = payload.phone || payload.user?.phone
    const otp = payload.otp || payload.sms?.otp

    if (!rawPhone || !otp) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'MISSING_PARAMETERS',
          message: 'Phone number and OTP code are required.',
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // Format phone number to international E.164 (without leading '+' for WhatsApp Graph API)
    let cleanPhone = rawPhone.replace(/\D/g, '')
    if (cleanPhone.startsWith('00')) {
      cleanPhone = cleanPhone.substring(2)
    }
    const whatsappRecipient = cleanPhone

    // Load WhatsApp API configuration from environment variables
    const whatsappApiKey = Deno.env.get('WHATSAPP_API_KEY') || Deno.env.get('WHATSAPP_ACCESS_TOKEN') || ''
    const whatsappPhoneNumberId = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID') || ''
    const templateName = Deno.env.get('WHATSAPP_TEMPLATE_NAME') || payload.template_name || ''

    // Optional Twilio WhatsApp configuration fallback
    const twilioAccountSid = Deno.env.get('TWILIO_ACCOUNT_SID') || ''
    const twilioAuthToken = Deno.env.get('TWILIO_AUTH_TOKEN') || ''
    const twilioWhatsAppNumber = Deno.env.get('TWILIO_WHATSAPP_NUMBER') || ''

    console.log(`[send-whatsapp-otp] Sending OTP to recipient: ${whatsappRecipient}`)

    // 1. Send via Meta WhatsApp Cloud API (Primary Provider)
    if (whatsappApiKey && whatsappPhoneNumberId) {
      const url = `https://graph.facebook.com/v18.0/${whatsappPhoneNumberId}/messages`

      let body: any
      if (templateName) {
        body = {
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: whatsappRecipient,
          type: 'template',
          template: {
            name: templateName,
            language: { code: 'ar' },
            components: [
              {
                type: 'body',
                parameters: [
                  { type: 'text', text: otp },
                ],
              },
              {
                type: 'button',
                sub_type: 'url',
                index: '0',
                parameters: [
                  { type: 'text', text: otp },
                ],
              },
            ],
          },
        }
      } else {
        body = {
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: whatsappRecipient,
          type: 'text',
          text: {
            preview_url: false,
            body: `رمز التحقق الخاص بك في كَفو هو: ${otp}\nيرجى عدم مشاركة الرمز مع أي شخص لحماية حسابك.`,
          },
        }
      }

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${whatsappApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
      })

      const resData = await response.json()

      if (!response.ok) {
        console.error('[send-whatsapp-otp] Meta API error:', resData)
        const metaError = resData.error || {}
        const errorCode = metaError.code
        const errorSubcode = metaError.error_subcode
        const errorMessage = (metaError.message || '').toLowerCase()

        // Handle error: recipient phone is not registered on WhatsApp
        if (
          errorCode === 131026 || 
          errorCode === 131051 || 
          errorSubcode === 131026 ||
          errorMessage.includes('not a valid whatsapp user') ||
          errorMessage.includes('recipient is not a valid') ||
          errorMessage.includes('not on whatsapp') ||
          errorMessage.includes('undeliverable')
        ) {
          return new Response(
            JSON.stringify({
              success: false,
              error: 'NOT_ON_WHATSAPP',
              code: errorCode,
              message: 'رقم الهاتف غير مسجل في تطبيق واتساب. يرجى التأكد من ربط الرقم بحساب واتساب نشط.',
            }),
            {
              status: 400,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            }
          )
        }

        return new Response(
          JSON.stringify({
            success: false,
            error: 'WHATSAPP_API_ERROR',
            details: metaError.message || 'Unknown WhatsApp API error',
            message: 'فشل إرسال رمز التحقق عبر واتساب. يرجى التأكد من صلاحية مفاتيح الربط.',
          }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        )
      }

      console.log('[send-whatsapp-otp] Sent successfully via Meta Cloud API:', resData)
      return new Response(
        JSON.stringify({
          success: true,
          provider: 'meta_cloud_api',
          message: 'تم إرسال رمز التحقق إلى حسابك في واتساب بنجاح.',
          messageId: resData.messages?.[0]?.id,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // 2. Send via Twilio WhatsApp API (Secondary / Fallback Provider)
    if (twilioAccountSid && twilioAuthToken && twilioWhatsAppNumber) {
      const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${twilioAccountSid}/Messages.json`
      const formData = new URLSearchParams()
      formData.append('From', twilioWhatsAppNumber.startsWith('whatsapp:') ? twilioWhatsAppNumber : `whatsapp:${twilioWhatsAppNumber}`)
      formData.append('To', `whatsapp:+${whatsappRecipient}`)
      formData.append('Body', `رمز التحقق الخاص بك في كَفو هو: ${otp}`)

      const credentials = btoa(`${twilioAccountSid}:${twilioAuthToken}`)
      const twilioRes = await fetch(twilioUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${credentials}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formData.toString(),
      })

      const twilioData = await twilioRes.json()
      if (!twilioRes.ok) {
        console.error('[send-whatsapp-otp] Twilio error:', twilioData)
        if (twilioData.code === 63007 || twilioData.code === 21614) {
          return new Response(
            JSON.stringify({
              success: false,
              error: 'NOT_ON_WHATSAPP',
              message: 'رقم الهاتف غير مسجل في تطبيق واتساب.',
            }),
            {
              status: 400,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            }
          )
        }

        return new Response(
          JSON.stringify({
            success: false,
            error: 'TWILIO_ERROR',
            details: twilioData.message,
          }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        )
      }

      return new Response(
        JSON.stringify({
          success: true,
          provider: 'twilio',
          message: 'تم إرسال رمز التحقق إلى حسابك في واتساب بنجاح.',
          messageId: twilioData.sid,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // 3. Fallback / Dev Warning
    console.warn('[send-whatsapp-otp] WHATSAPP_API_KEY is not configured yet in .env.')
    return new Response(
      JSON.stringify({
        success: true,
        mock: true,
        message: 'تم استقبال طلب رمز التحقق (وضع التجربة - بانتظار إدخال WHATSAPP_API_KEY في ملف .env).',
        recipient: whatsappRecipient,
        otp: otp,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )

  } catch (error) {
    console.error('[send-whatsapp-otp] Server error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: 'INTERNAL_SERVER_ERROR',
        message: error instanceof Error ? error.message : 'Unknown server error',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})