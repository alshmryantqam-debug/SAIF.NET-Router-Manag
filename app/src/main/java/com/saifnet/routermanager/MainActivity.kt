
package com.saifnet.routermanager

import android.app.Activity
import android.os.Bundle
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import kotlin.random.Random

class MainActivity : Activity() {

    private val purple = Color.rgb(145, 70, 255)
    private val backgroundColor = Color.rgb(16, 13, 28)
    private val cardColor = Color.rgb(33, 27, 49)

    private lateinit var cpu: TextView
    private lateinit var ram: TextView
    private lateinit var temp: TextView
    private lateinit var wan: TextView
    private lateinit var updated: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = backgroundColor
        window.navigationBarColor = backgroundColor
        createDashboard()
        refreshDemo()
    }

    private fun label(text: String, size: Float): TextView {
        return TextView(this).apply {
            this.text = text
            textSize = size
            setTextColor(Color.WHITE)
            gravity = Gravity.RIGHT
            textDirection = TextView.TEXT_DIRECTION_RTL
        }
    }

    private fun createDashboard() {
        val scroll = ScrollView(this)
        scroll.setBackgroundColor(backgroundColor)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(20, 24, 20, 24)
            layoutDirection = LinearLayout.LAYOUT_DIRECTION_RTL
        }

        root.addView(label("SAIF.NET", 30f).apply {
            setTextColor(purple)
            setTypeface(null, Typeface.BOLD)
        })

        root.addView(label("إدارة شبكة الإنترنت", 18f))
        root.addView(label("لوحة مراقبة الراوتر • وضع تجريبي", 13f).apply {
            setTextColor(Color.LTGRAY)
            setPadding(0, 8, 0, 20)
        })

        root.addView(label("حالة النظام", 20f).apply {
            setTypeface(null, Typeface.BOLD)
            setPadding(0, 8, 0, 12)
        })

        cpu = addCard(root, "استخدام المعالج CPU")
        ram = addCard(root, "استخدام الذاكرة RAM")
        temp = addCard(root, "حرارة الجهاز")
        wan = addCard(root, "حالة خطوط الإنترنت")

        root.addView(label("الخطوط المتصلة", 20f).apply {
            setTypeface(null, Typeface.BOLD)
            setPadding(0, 18, 0, 8)
        })

        root.addView(label("Starlink 1   •   تجريبي", 16f))
        root.addView(label("Starlink 2   •   تجريبي", 16f))
        root.addView(label("الخط التركي   •   تجريبي", 16f))

        val refresh = Button(this).apply {
            text = "تحديث البيانات التجريبية"
            setTextColor(Color.WHITE)
            setBackgroundColor(purple)
            setOnClickListener { refreshDemo() }
        }

        root.addView(refresh)

        updated = label("البيانات تجريبية وليست من الراوتر", 13f).apply {
            setTextColor(Color.LTGRAY)
            setPadding(0, 16, 0, 0)
        }
        root.addView(updated)

        scroll.addView(root)
        setContentView(scroll)
    }

    private fun addCard(root: LinearLayout, title: String): TextView {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(16, 14, 16, 14)
            setBackgroundColor(cardColor)
        }

        card.addView(label(title, 15f).apply {
            setTextColor(Color.LTGRAY)
        })

        val value = label("--", 25f).apply {
            setTextColor(purple)
            setTypeface(null, Typeface.BOLD)
            setPadding(0, 8, 0, 0)
        }

        card.addView(value)

        val params = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        params.bottomMargin = 12
        root.addView(card, params)

        return value
    }

    private fun refreshDemo() {
        cpu.text = "${Random.nextInt(8, 46)}%"
        ram.text = "${Random.nextInt(25, 71)}%"
        temp.text = "${Random.nextInt(40, 66)} °C"
        wan.text = "3 خطوط • حالة تجريبية"
        updated.text = "تم تحديث العرض التجريبي"
    }
}
