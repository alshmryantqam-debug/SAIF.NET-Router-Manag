package com.saifnet.routermanager

import android.app.Activity
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import okhttp3.*
import okhttp3.Credentials
import org.json.JSONArray
import java.io.IOException

class MainActivity : Activity() {

    // --- إعدادات المايكروتيك (يجب تغييرها لتطابق شبكتك) ---
    // ضع عنوان IP الخاص براوتر CCR2116
    private val ROUTER_IP = "192.168.88.1" 
    // ضع اسم المستخدم وكلمة المرور التي أنشأتها للـ API
    private val API_USER = "app_user"
    private val API_PASS = "123456"

    // ألوان الهوية البصرية
    private val accentPurple = Color.parseColor("#9D4EDD")
    private val accentGreen = Color.parseColor("#06D6A0")
    private val textPrimary = Color.parseColor("#FFFFFF")
    private val textSecondary = Color.parseColor("#A0A0B0")
    private val Int.dp: Int get() = (this * resources.displayMetrics.density).toInt()

    private lateinit var cpuBar: ProgressBar
    private lateinit var cpuText: TextView
    private lateinit var ramBar: ProgressBar
    private lateinit var ramText: TextView
    private lateinit var activeUsersText: TextView
    
    // عميل OkHttp للاتصال بالشبكة
    private val client = OkHttpClient()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val mainBackground = GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            intArrayOf(Color.parseColor("#0F0C29"), Color.parseColor("#302B63"), Color.parseColor("#24243E"))
        )
        
        window.statusBarColor = Color.parseColor("#0F0C29")
        window.navigationBarColor = Color.parseColor("#24243E")

        val scroll = ScrollView(this).apply {
            background = mainBackground
            isFillViewport = true
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(20.dp, 30.dp, 20.dp, 30.dp)
            layoutDirection = LinearLayout.LAYOUT_DIRECTION_RTL
        }

        buildHeader(root)
        buildVitalsSection(root)
        buildLinesSection(root)
        buildQuickActions(root)

        scroll.addView(root)
        setContentView(scroll)

        // جلب البيانات فور تشغيل التطبيق
        fetchRouterData()
    }

    private fun buildHeader(root: LinearLayout) {
        root.addView(TextView(this).apply {
            text = "SAIF.NET PLATFORM"
            textSize = 28f
            setTextColor(accentPurple)
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.RIGHT
            letterSpacing = 0.05f
        })
        root.addView(TextView(this).apply {
            text = "مركز القيادة والتحكم الآلي • متصل بالراوتر"
            textSize = 14f
            setTextColor(accentGreen)
            gravity = Gravity.RIGHT
            setPadding(0, 0, 0, 24.dp)
        })
    }

    private fun buildVitalsSection(root: LinearLayout) {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            weightSum = 2f
        }

        val cpuCard = createGlassCard()
        cpuCard.layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { marginEnd = 8.dp }
        cpuCard.addView(createLabel("المعالج (CPU)", textSecondary, 12f))
        cpuText = createLabel("--%", textPrimary, 24f, true)
        cpuCard.addView(cpuText)
        cpuBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            progressTintList = ColorStateList.valueOf(accentPurple)
            setPadding(0, 8.dp, 0, 0)
        }
        cpuCard.addView(cpuBar)

        val ramCard = createGlassCard()
        ramCard.layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { marginStart = 8.dp }
        ramCard.addView(createLabel("الذاكرة (RAM)", textSecondary, 12f))
        ramText = createLabel("--%", textPrimary, 24f, true)
        ramCard.addView(ramText)
        ramBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            progressTintList = ColorStateList.valueOf(Color.parseColor("#48BFE3"))
            setPadding(0, 8.dp, 0, 0)
        }
        ramCard.addView(ramBar)

        row.addView(cpuCard)
        row.addView(ramCard)
        root.addView(row)

        val usersCard = createGlassCard().apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = 16.dp }
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        
        val userTextLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }
        userTextLayout.addView(createLabel("المشتركين المتصلين حالياً (PPPoE & Hotspot)", textSecondary, 12f))
        activeUsersText = createLabel("جاري الاتصال...", accentGreen, 20f, true)
        userTextLayout.addView(activeUsersText)
        
        usersCard.addView(userTextLayout)
        root.addView(usersCard)
    }

    private fun buildLinesSection(root: LinearLayout) {
        root.addView(createLabel("مراقبة دمج الخطوط (PCC)", textPrimary, 16f, true).apply {
            setPadding(0, 24.dp, 0, 12.dp)
        })
        root.addView(createLineStatus("Starlink 1", true, "جاهز"))
        root.addView(createLineStatus("Starlink 2", true, "جاهز"))
        root.addView(createLineStatus("الخط التركي", true, "جاهز"))
    }

    private fun buildQuickActions(root: LinearLayout) {
        root.addView(createLabel("إجراءات", textPrimary, 16f, true).apply { setPadding(0, 24.dp, 0, 12.dp) })
        val btnRefresh = Button(this).apply {
            text = "تحديث البيانات من الراوتر"
            setTextColor(Color.WHITE)
            background = createGradientDrawable(Color.parseColor("#7209B7"), Color.parseColor("#3A0CA3"), 12.dp.toFloat())
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 50.dp)
            setOnClickListener { 
                cpuText.text = "..."
                ramText.text = "..."
                activeUsersText.text = "..."
                fetchRouterData() 
            }
        }
        root.addView(btnRefresh)
    }

    // --- الاتصال الفعلي بالراوتر ---
    private fun fetchRouterData() {
        // إنشاء رابط طلب حالة النظام من RouterOS v7 REST API
        val url = "http://$ROUTER_IP/rest/system/resource"
        
        // إعداد بيانات تسجيل الدخول
        val credential = Credentials.basic(API_USER, API_PASS)
        
        val request = Request.Builder()
            .url(url)
            .header("Authorization", credential)
            .build()

        // إرسال الطلب في مسار منفصل (Background Thread) لكي لا يتجمد التطبيق
        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("SaifNetAPI", "فشل الاتصال: ${e.message}")
                updateUIOnError()
            }

            override fun onResponse(call: Call, response: Response) {
                if (response.isSuccessful) {
                    val responseData = response.body?.string()
                    try {
                        // الراوتر يرسل البيانات على شكل مصفوفة JSON
                        val jsonArray = JSONArray(responseData)
                        val resourceObj = jsonArray.getJSONObject(0)
                        
                        // استخراج المعالج
                        val cpuLoad = resourceObj.getInt("cpu-load")
                        
                        // حساب الذاكرة المستخدمة: (إجمالي الذاكرة - الذاكرة الحرة) / إجمالي الذاكرة * 100
                        val totalMem = resourceObj.getLong("total-memory")
                        val freeMem = resourceObj.getLong("free-memory")
                        val usedMem = totalMem - freeMem
                        val ramPercent = ((usedMem.toDouble() / totalMem.toDouble()) * 100).toInt()

                        // تحديث الواجهة بالأرقام الحقيقية (يجب أن يتم على مسار الواجهة الرئيسي)
                        runOnUiThread {
                            cpuText.text = "$cpuLoad%"
                            cpuBar.progress = cpuLoad
                            
                            ramText.text = "$ramPercent%"
                            ramBar.progress = ramPercent
                            
                            activeUsersText.text = "تم الاتصال بالراوتر بنجاح"
                            activeUsersText.setTextColor(accentGreen)
                        }
                    } catch (e: Exception) {
                        Log.e("SaifNetAPI", "خطأ في قراءة البيانات: ${e.message}")
                        updateUIOnError()
                    }
                } else {
                    Log.e("SaifNetAPI", "خطأ من الراوتر، الكود: ${response.code}")
                    updateUIOnError()
                }
            }
        })
    }

    private fun updateUIOnError() {
        runOnUiThread {
            cpuText.text = "خطأ"
            ramText.text = "خطأ"
            activeUsersText.text = "فشل الاتصال بالراوتر (تأكد من الـ IP واسم المستخدم)"
            activeUsersText.setTextColor(Color.RED)
            cpuBar.progress = 0
            ramBar.progress = 0
        }
    }

    // --- دوال التصميم ---
    private fun createGlassCard(): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = createGlassDrawable()
            setPadding(16.dp, 16.dp, 16.dp, 16.dp)
        }
    }
    private fun createGlassDrawable(): GradientDrawable {
        return GradientDrawable().apply {
            setColor(Color.parseColor("#1AFFFFFF"))
            cornerRadius = 16.dp.toFloat()
            setStroke(1.dp, Color.parseColor("#33FFFFFF"))
        }
    }
    private fun createGradientDrawable(color1: Int, color2: Int, radius: Float): GradientDrawable {
        return GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, intArrayOf(color1, color2)).apply { cornerRadius = radius }
    }
    private fun createLabel(textStr: String, color: Int, size: Float, isBold: Boolean = false): TextView {
        return TextView(this).apply {
            text = textStr
            textSize = size
            setTextColor(color)
            if (isBold) setTypeface(null, Typeface.BOLD)
            gravity = Gravity.RIGHT
        }
    }
    private fun createLineStatus(name: String, isOnline: Boolean, speed: String): LinearLayout {
        val card = createGlassCard().apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { bottomMargin = 8.dp }
        }
        val dot = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(12.dp, 12.dp).apply { marginEnd = 12.dp }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(if (isOnline) accentGreen else Color.RED)
            }
        }
        val nameText = createLabel(name, textPrimary, 14f).apply {
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
            gravity = Gravity.RIGHT
        }
        card.addView(createLabel(speed, textSecondary, 12f))
        card.addView(nameText)
        card.addView(dot)
        return card
    }
}
