package com.saifnet.routermanager

import android.app.Activity
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import kotlin.random.Random

class MainActivity : Activity() {

    // ألوان الهوية البصرية لـ SAIF.NET
    private val accentPurple = Color.parseColor("#9D4EDD")
    private val accentGreen = Color.parseColor("#06D6A0")
    private val textPrimary = Color.parseColor("#FFFFFF")
    private val textSecondary = Color.parseColor("#A0A0B0")

    // تحويل الأرقام إلى DP لتتناسب مع جميع الشاشات
    private val Int.dp: Int get() = (this * resources.displayMetrics.density).toInt()

    private lateinit var cpuBar: ProgressBar
    private lateinit var cpuText: TextView
    private lateinit var ramBar: ProgressBar
    private lateinit var ramText: TextView
    private lateinit var activeUsersText: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // خلفية متدرجة احترافية (Dark Gradient)
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

        simulateRealtimeData()
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
            text = "مركز القيادة والتحكم الآلي"
            textSize = 14f
            setTextColor(textSecondary)
            gravity = Gravity.RIGHT
            setPadding(0, 0, 0, 24.dp)
        })
    }

    private fun buildVitalsSection(root: LinearLayout) {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            weightSum = 2f
        }

        // بطاقة المعالج
        val cpuCard = createGlassCard()
        val cpuParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        cpuParams.marginEnd = 8.dp
        cpuCard.layoutParams = cpuParams
        
        cpuCard.addView(createLabel("المعالج (CPU)", textSecondary, 12f))
        cpuText = createLabel("0%", textPrimary, 24f, true)
        cpuCard.addView(cpuText)
        cpuBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            progressTintList = ColorStateList.valueOf(accentPurple)
            setPadding(0, 8.dp, 0, 0)
        }
        cpuCard.addView(cpuBar)

        // بطاقة الذاكرة
        val ramCard = createGlassCard()
        val ramParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        ramParams.marginStart = 8.dp
        ramCard.layoutParams = ramParams

        ramCard.addView(createLabel("الذاكرة (RAM)", textSecondary, 12f))
        ramText = createLabel("0%", textPrimary, 24f, true)
        ramCard.addView(ramText)
        ramBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            progressTintList = ColorStateList.valueOf(Color.parseColor("#48BFE3"))
            setPadding(0, 8.dp, 0, 0)
        }
        ramCard.addView(ramBar)

        row.addView(cpuCard)
        row.addView(ramCard)
        root.addView(row)

        // بطاقة المستخدمين النشطين
        val usersCard = createGlassCard().apply {
            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            params.topMargin = 16.dp
            layoutParams = params
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        
        val userTextLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }
        userTextLayout.addView(createLabel("إجمالي المشتركين النشطين (PPPoE & Hotspot)", textSecondary, 12f))
        activeUsersText = createLabel("230", accentGreen, 28f, true)
        userTextLayout.addView(activeUsersText)
        
        usersCard.addView(userTextLayout)
        root.addView(usersCard)
    }

    private fun buildLinesSection(root: LinearLayout) {
        root.addView(createLabel("مراقبة دمج الخطوط (PCC)", textPrimary, 16f, true).apply {
            setPadding(0, 24.dp, 0, 12.dp)
        })

        root.addView(createLineStatus("Starlink - الخط الأول", true, "120 Mbps"))
        root.addView(createLineStatus("Starlink - الخط الثاني", true, "95 Mbps"))
        root.addView(createLineStatus("الخط التركي الأساسي", true, "210 Mbps"))
    }

    private fun buildQuickActions(root: LinearLayout) {
        root.addView(createLabel("إجراءات سريعة", textPrimary, 16f, true).apply {
            setPadding(0, 24.dp, 0, 12.dp)
        })

        val btnQueues = Button(this).apply {
            text = "إدارة سرعات المشتركين (Queues)"
            setTextColor(Color.WHITE)
            background = createGradientDrawable(Color.parseColor("#7209B7"), Color.parseColor("#3A0CA3"), 12.dp.toFloat())
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 50.dp).apply { bottomMargin = 12.dp }
        }
        
        val btnRefresh = Button(this).apply {
            text = "مزامنة البيانات مع الراوتر"
            setTextColor(accentPurple)
            background = createGlassDrawable()
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 50.dp)
            setOnClickListener { simulateRealtimeData() }
        }

        root.addView(btnQueues)
        root.addView(btnRefresh)
    }

    // --- الدوال المساعدة للتصميم (UI Helpers) ---

    private fun createGlassCard(): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = createGlassDrawable()
            setPadding(16.dp, 16.dp, 16.dp, 16.dp)
        }
    }

    private fun createGlassDrawable(): GradientDrawable {
        return GradientDrawable().apply {
            setColor(Color.parseColor("#1AFFFFFF")) // شفافية 10%
            cornerRadius = 16.dp.toFloat()
            setStroke(1.dp, Color.parseColor("#33FFFFFF")) // إطار زجاجي خفيف
        }
    }
    
    private fun createGradientDrawable(color1: Int, color2: Int, radius: Float): GradientDrawable {
        return GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, intArrayOf(color1, color2)).apply {
            cornerRadius = radius
        }
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
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = 8.dp
            }
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
        
        val speedText = createLabel(speed, textSecondary, 12f)

        card.addView(speedText)
        card.addView(nameText)
        card.addView(dot)
        
        return card
    }

    // محاكاة البيانات ريثما نربط التطبيق بالراوتر الفعلي
    private fun simulateRealtimeData() {
        val cpuVal = Random.nextInt(10, 85)
        val ramVal = Random.nextInt(40, 92)
        
        cpuText.text = "$cpuVal%"
        cpuBar.progress = cpuVal
        
        ramText.text = "$ramVal%"
        ramBar.progress = ramVal
        
        activeUsersText.text = Random.nextInt(210, 245).toString()
    }
}
