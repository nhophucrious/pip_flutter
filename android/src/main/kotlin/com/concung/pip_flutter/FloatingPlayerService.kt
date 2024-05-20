package com.concung.pip_flutter

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.*
import android.widget.RelativeLayout

class FloatingPlayerService : Service() {

    private  var windowManager: WindowManager?=null
    private var view: View?=null
    private var params: WindowManager.LayoutParams? = null
    var paramsDefault: RelativeLayout.LayoutParams? = null
    var lastAction = 0
    var layoutRes:Int?=null
    private var firstInitView = true
    fun create(layoutRes:Int) {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        windowManager!!.addView(getView(layoutRes), getParamViews())
    }
    override fun onBind(intent: Intent?): IBinder? = null

     fun getParamViews(): WindowManager.LayoutParams? {
        if (params == null) params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                getWindowType(),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT
        )
        params!!.y = 100
        params!!.x = 100
        return params
    }
    fun getWindowType(): Int {
        // Set to TYPE_SYSTEM_ALERT so that the Service can display it
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE
    }
    override fun onCreate() {
        super.onCreate()
        val layoutRes = R.layout.float_screen
        setUp(layoutRes)
        view = getView(layoutRes)!!
    }
    fun getView(layoutRes:Int): View? {
        if (view == null) {
            view = View.inflate(this, layoutRes, null)
        }
        return view
    }

    fun setUp(layoutRes:Int) {
        val ROOT_CONTAINER_ID = getViewRootId()
        create(layoutRes)
        val floatingView: View = getView(layoutRes)!!
        val rootContainer = floatingView.findViewById<View>(ROOT_CONTAINER_ID)
        if(firstInitView) {
            paramsDefault = rootContainer.layoutParams as RelativeLayout.LayoutParams
            val params = RelativeLayout.LayoutParams(rootContainer.width, rootContainer.height)

            //params.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM);
            params.addRule(RelativeLayout.ALIGN_PARENT_RIGHT)
            params.topMargin = 0
            params.rightMargin = 0
            //rootContainer.setLayoutParams(params);
        }
        run(rootContainer,floatingView)
        firstInitView = false
    }

    fun getViewRootId(): Int {
        return getResources().getIdentifier("root_container", "id", getPackageName())
    }

    fun run(rootContainer:View?,baseView:View) {
        if (rootContainer != null) { // get position for moving
            rootContainer.setOnTouchListener(object : View.OnTouchListener {
                private var initialX = 0
                private var initialY = 0
                private var initialTouchX = 0f
                private var initialTouchY = 0f
                override fun onTouch(v: View, event: MotionEvent): Boolean {
                    when (event.action) {
                        MotionEvent.ACTION_DOWN -> {
                            //remember the initial position.
                            lastAction = MotionEvent.ACTION_DOWN
                            initialX = params!!.x
                            initialY = params!!.y
                            //get the touch location
                            initialTouchX = event.rawX
                            initialTouchY = event.rawY
                            return true
                        }
                        MotionEvent.ACTION_MOVE -> {
                            //Calculate the X and Y coordinates of the view.
                            lastAction = MotionEvent.ACTION_MOVE
                            params!!.x = (initialX + (event.rawX - initialTouchX)).toInt()
                            params!!.y = (initialY + (event.rawY - initialTouchY)).toInt()
                            if (event.rawX - initialTouchX == 0f && event.rawY - initialTouchY == 0f) {
                                lastAction = MotionEvent.ACTION_DOWN
                            }
                            //Update the layout with new X & Y coordinate
                            windowManager!!.updateViewLayout(baseView, params)
                            return true
                        }
                        MotionEvent.ACTION_UP -> {
                            //Calculate the X and Y coordinates of the view.

                            return true
                        }
                    }
                    return false
                }
            })
        }
    }
    override fun onDestroy() {
        try {
            if (windowManager != null) if (view != null) windowManager!!.removeViewImmediate(view)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        } finally {
            params = null
            view = null
            windowManager = null
        }
        super.onDestroy()

    }
}