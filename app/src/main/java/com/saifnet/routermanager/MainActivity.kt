package com.saifnet.routermanager

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import com.google.android.material.progressindicator.LinearProgressIndicator
import okhttp3.*
import org.json.JSONArray
import java.io.IOException

class MainActivity : Activity() {

    // --- إعدادات سيف نت ---
    private val ROUTER_IP = "192.168.88.1"
    private val API_USER = "app_user"
    private val API_PASS = "123456"

    private lateinit var statusText: TextView
    private lateinit var cpuText: TextView
    private lateinit var ramText: TextView
    private lateinit var totalDownload: TextView
    private lateinit var totalUpload: TextView
    private lateinit var cpuBar: LinearProgressIndicator
    private lateinit var ramBar: LinearProgressIndicator
    
    private val client = OkHttpClient()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // شريط مهام أسود بالكامل ليناسب الهوية الفضائية
        window.statusBarColor = Color.parseColor("#05070A")
        window.navigationBarColor = Color.parseColor("#05070A")

        setContentView(R.layout.activity_main)

        statusText = findViewById(R.id.statusText)
        cpuText = findViewById(R.id.cpuText)
        ramText = findViewById(R.id.ramText)
        totalDownload = findViewById(R.id.totalDownload)
        totalUpload = findViewById(R.id.totalUpload)
        cpuBar = findViewById(R.id.cpuBar)
        ramBar = findViewById(R.id.ramBar)
        
        findViewById<Button>(R.id.btnRefresh).setOnClickListener {
            statusText.text = "جاري الاتصال بالخوادم..."
            statusText.setTextColor(Color.parseColor("#B388FF"))
            fetchRouterData()
        }

        fetchRouterData()
    }

    private fun fetchRouterData() {
        val url = "http://$ROUTER_IP/rest/system/resource"
        val credential = Credentials.basic(API_USER, API_PASS)
        val request = Request.Builder().url(url).header("Authorization", credential).build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                runOnUiThread { updateUIOnError() }
            }

            override fun onResponse(call: Call, response: Response) {
                if (response.isSuccessful) {
                    val responseData = response.body?.string()
                    try {
                        val jsonArray = JSONArray(responseData)
                        val res = jsonArray.getJSONObject(0)
                        
                        val cpuLoad = res.getInt("cpu-load")
                        val totalMem = res.getLong("total-memory")
                        val freeMem = res.getLong("free-memory")
                        val ramPercent = (((totalMem - freeMem).toDouble() / totalMem) * 100).toInt()

                        runOnUiThread {
                            cpuText.text = "$cpuLoad%"
                            cpuBar.setProgressCompat(cpuLoad, true) // حركة أنيميشن ناعمة
                            
                            ramText.text = "$ramPercent%"
                            ramBar.setProgressCompat(ramPercent, true)
                            
                            statusText.text = "متصل بالراوتر • البث مستقر"
                            statusText.setTextColor(Color.parseColor("#00E676"))

                            // قيم مؤقتة ريثما نربط واجهة (Interfaces) الخاصة بالـ Traffic
                            totalDownload.text = "214 Mbps"
                            totalUpload.text = "48 Mbps"
                        }
                    } catch (e: Exception) {
                        runOnUiThread { updateUIOnError() }
                    }
                } else {
                    runOnUiThread { updateUIOnError() }
                }
            }
        })
    }

    private fun updateUIOnError() {
        statusText.text = "تم فقدان الاتصال بالراوتر (CRITICAL ERROR)"
        statusText.setTextColor(Color.parseColor("#FF1744"))
        cpuText.text = "--%"
        ramText.text = "--%"
        cpuBar.setProgressCompat(0, true)
        ramBar.setProgressCompat(0, true)
    }
}
