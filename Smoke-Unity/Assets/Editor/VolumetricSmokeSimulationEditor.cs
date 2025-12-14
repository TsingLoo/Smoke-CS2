#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(VolumetricSmokeSimulation))]
public class VolumetricSmokeSimulationEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        VolumetricSmokeSimulation smoke = (VolumetricSmokeSimulation)target;

        EditorGUILayout.Space(10);
        EditorGUILayout.LabelField("Runtime Status", EditorStyles.boldLabel);

        // 显示当前状态
        using (new EditorGUI.DisabledGroupScope(true))
        {
            EditorGUILayout.EnumPopup("Current Phase", smoke.CurrentPhase);
            
            // 预计算进度
            if (smoke.CurrentPhase == VolumetricSmokeSimulation.SmokePhase.Precomputing)
            {
                Rect precomputeRect = EditorGUILayout.GetControlRect(false, 18);
                EditorGUI.ProgressBar(precomputeRect, smoke.PrecomputeProgress, 
                    $"Precomputing: {smoke.PrecomputedCount} / {GetMaxBudget(smoke)}");
            }
            
            EditorGUILayout.Slider("Phase Progress", smoke.PhaseProgress, 0f, 1f);
            EditorGUILayout.IntField("Precomputed Voxels", smoke.PrecomputedCount);
            EditorGUILayout.IntField("Visible Voxels", smoke.VisibleCount);
        }

        // 绘制阶段进度条
        EditorGUILayout.Space(5);
        EditorGUILayout.LabelField("Phase Timeline", EditorStyles.miniBoldLabel);
        Rect progressRect = EditorGUILayout.GetControlRect(false, 24);
        DrawPhaseProgressBar(progressRect, smoke);

        // 绘制Voxel数量曲线预览
        EditorGUILayout.Space(5);
        EditorGUILayout.LabelField("Voxel Count Preview", EditorStyles.miniBoldLabel);
        Rect curveRect = EditorGUILayout.GetControlRect(false, 60);
        DrawVoxelCountPreview(curveRect, smoke);

        // 控制按钮
        EditorGUILayout.Space(10);
        EditorGUILayout.LabelField("Controls", EditorStyles.boldLabel);

        using (new EditorGUI.DisabledGroupScope(!Application.isPlaying))
        {
            EditorGUILayout.BeginHorizontal();

            if (GUILayout.Button("Replay", GUILayout.Height(25)))
            {
                smoke.Replay();
            }

            if (GUILayout.Button("Force Complete\nPrecompute", GUILayout.Height(25)))
            {
                smoke.ForceCompletePrecompute();
            }

            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();

            GUI.enabled = Application.isPlaying && 
                          smoke.CurrentPhase != VolumetricSmokeSimulation.SmokePhase.Precomputing;

            if (GUILayout.Button("→ Burst"))
            {
                smoke.ForceTransitionTo(VolumetricSmokeSimulation.SmokePhase.Burst);
            }

            if (GUILayout.Button("→ Spread"))
            {
                smoke.ForceTransitionTo(VolumetricSmokeSimulation.SmokePhase.Spread);
            }

            if (GUILayout.Button("→ Dissipate"))
            {
                smoke.ForceTransitionTo(VolumetricSmokeSimulation.SmokePhase.Dissipate);
            }

            if (GUILayout.Button("→ Idle"))
            {
                smoke.ForceTransitionTo(VolumetricSmokeSimulation.SmokePhase.Idle);
            }

            GUI.enabled = true;

            EditorGUILayout.EndHorizontal();
        }

        // 在播放模式下强制重绘
        if (Application.isPlaying)
        {
            Repaint();
        }
    }

    int GetMaxBudget(VolumetricSmokeSimulation smoke)
    {
        var so = new SerializedObject(smoke);
        return so.FindProperty("maxPrecomputeBudget").intValue;
    }

    void DrawPhaseProgressBar(Rect rect, VolumetricSmokeSimulation smoke)
    {
        // 背景
        EditorGUI.DrawRect(rect, new Color(0.15f, 0.15f, 0.15f));

        Color precomputeColor = new Color(0.4f, 0.4f, 0.4f);
        Color burstColor = new Color(1f, 0.4f, 0.1f);
        Color spreadColor = new Color(0.3f, 0.7f, 1f);
        Color dissipateColor = new Color(0.6f, 0.4f, 0.8f);

        float totalDuration = smoke.burstDuration + smoke.spreadDuration + smoke.dissipateDuration;
        if (totalDuration <= 0) return;

        float burstWidth = (smoke.burstDuration / totalDuration) * rect.width;
        float spreadWidth = (smoke.spreadDuration / totalDuration) * rect.width;
        float dissipateWidth = (smoke.dissipateDuration / totalDuration) * rect.width;

        // 绘制底色
        EditorGUI.DrawRect(new Rect(rect.x, rect.y, burstWidth, rect.height), burstColor * 0.25f);
        EditorGUI.DrawRect(new Rect(rect.x + burstWidth, rect.y, spreadWidth, rect.height), spreadColor * 0.25f);
        EditorGUI.DrawRect(new Rect(rect.x + burstWidth + spreadWidth, rect.y, dissipateWidth, rect.height), dissipateColor * 0.25f);

        // 绘制当前进度
        float currentX = rect.x;
        float fillWidth = 0;
        Color fillColor = Color.white;

        switch (smoke.CurrentPhase)
        {
            case VolumetricSmokeSimulation.SmokePhase.Precomputing:
                EditorGUI.DrawRect(rect, precomputeColor * 0.5f);
                GUIStyle preStyle = new GUIStyle(EditorStyles.boldLabel);
                preStyle.alignment = TextAnchor.MiddleCenter;
                preStyle.normal.textColor = Color.white;
                GUI.Label(rect, "⏳ Precomputing...", preStyle);
                return;
                
            case VolumetricSmokeSimulation.SmokePhase.Burst:
                fillWidth = burstWidth * smoke.PhaseProgress;
                fillColor = burstColor;
                break;
                
            case VolumetricSmokeSimulation.SmokePhase.Spread:
                currentX = rect.x + burstWidth;
                fillWidth = spreadWidth * smoke.PhaseProgress;
                fillColor = spreadColor;
                EditorGUI.DrawRect(new Rect(rect.x, rect.y, burstWidth, rect.height), burstColor);
                break;
                
            case VolumetricSmokeSimulation.SmokePhase.Dissipate:
                currentX = rect.x + burstWidth + spreadWidth;
                fillWidth = dissipateWidth * smoke.PhaseProgress;
                fillColor = dissipateColor;
                EditorGUI.DrawRect(new Rect(rect.x, rect.y, burstWidth, rect.height), burstColor);
                EditorGUI.DrawRect(new Rect(rect.x + burstWidth, rect.y, spreadWidth, rect.height), spreadColor);
                break;
                
            case VolumetricSmokeSimulation.SmokePhase.Idle:
                break;
        }

        if (fillWidth > 0)
        {
            EditorGUI.DrawRect(new Rect(currentX, rect.y, fillWidth, rect.height), fillColor);
        }

        // 分隔线
        EditorGUI.DrawRect(new Rect(rect.x + burstWidth - 1, rect.y, 2, rect.height), Color.black);
        EditorGUI.DrawRect(new Rect(rect.x + burstWidth + spreadWidth - 1, rect.y, 2, rect.height), Color.black);

        // 标签
        GUIStyle labelStyle = new GUIStyle(EditorStyles.miniLabel);
        labelStyle.alignment = TextAnchor.MiddleCenter;
        labelStyle.normal.textColor = Color.white;

        GUI.Label(new Rect(rect.x, rect.y, burstWidth, rect.height), "Burst", labelStyle);
        GUI.Label(new Rect(rect.x + burstWidth, rect.y, spreadWidth, rect.height), "Spread", labelStyle);
        GUI.Label(new Rect(rect.x + burstWidth + spreadWidth, rect.y, dissipateWidth, rect.height), "Dissipate", labelStyle);
    }

    void DrawVoxelCountPreview(Rect rect, VolumetricSmokeSimulation smoke)
    {
        // 背景
        EditorGUI.DrawRect(rect, new Color(0.1f, 0.1f, 0.1f));

        var so = new SerializedObject(smoke);
        int maxBudget = so.FindProperty("maxPrecomputeBudget").intValue;
        float burstRatio = so.FindProperty("burstTargetRatio").floatValue;
        float spreadRatio = so.FindProperty("spreadTargetRatio").floatValue;

        int burstTarget = Mathf.RoundToInt(maxBudget * burstRatio);
        int spreadTarget = Mathf.RoundToInt(maxBudget * spreadRatio);

        float totalDuration = smoke.burstDuration + smoke.spreadDuration + smoke.dissipateDuration;
        if (totalDuration <= 0 || maxBudget <= 0) return;

        float burstTimeRatio = smoke.burstDuration / totalDuration;
        float spreadTimeRatio = smoke.spreadDuration / totalDuration;

        // 绘制曲线
        Handles.BeginGUI();
        
        Color curveColor = new Color(0.2f, 0.8f, 0.3f);
        Handles.color = curveColor;

        int segments = 100;
        Vector3 prevPoint = Vector3.zero;

        for (int i = 0; i <= segments; i++)
        {
            float t = (float)i / segments;
            float normalizedY = 0f;

            if (t < burstTimeRatio)
            {
                float localT = t / burstTimeRatio;
                float curveVal = smoke.burstProgressCurve.Evaluate(localT);
                normalizedY = curveVal * burstRatio;
            }
            else if (t < burstTimeRatio + spreadTimeRatio)
            {
                float localT = (t - burstTimeRatio) / spreadTimeRatio;
                float curveVal = smoke.spreadProgressCurve.Evaluate(localT);
                normalizedY = Mathf.Lerp(burstRatio, spreadRatio, curveVal);
            }
            else
            {
                normalizedY = spreadRatio;
            }

            float x = rect.x + t * rect.width;
            float y = rect.y + rect.height - (normalizedY * rect.height);

            Vector3 point = new Vector3(x, y, 0);

            if (i > 0)
            {
                Handles.DrawLine(prevPoint, point);
            }

            prevPoint = point;
        }

        // 绘制当前位置指示器
        if (smoke.CurrentPhase != VolumetricSmokeSimulation.SmokePhase.Idle &&
            smoke.CurrentPhase != VolumetricSmokeSimulation.SmokePhase.Precomputing)
        {
            float currentT = 0f;
            float currentY = 0f;

            switch (smoke.CurrentPhase)
            {
                case VolumetricSmokeSimulation.SmokePhase.Burst:
                    currentT = smoke.PhaseProgress * burstTimeRatio;
                    currentY = smoke.burstProgressCurve.Evaluate(smoke.PhaseProgress) * burstRatio;
                    break;
                case VolumetricSmokeSimulation.SmokePhase.Spread:
                    currentT = burstTimeRatio + smoke.PhaseProgress * spreadTimeRatio;
                    currentY = Mathf.Lerp(burstRatio, spreadRatio, 
                        smoke.spreadProgressCurve.Evaluate(smoke.PhaseProgress));
                    break;
                case VolumetricSmokeSimulation.SmokePhase.Dissipate:
                    currentT = burstTimeRatio + spreadTimeRatio + 
                               smoke.PhaseProgress * (1f - burstTimeRatio - spreadTimeRatio);
                    currentY = spreadRatio;
                    break;
            }

            float markerX = rect.x + currentT * rect.width;
            float markerY = rect.y + rect.height - (currentY * rect.height);

            Handles.color = Color.white;
            Handles.DrawSolidDisc(new Vector3(markerX, markerY, 0), Vector3.forward, 4f);
            Handles.color = Color.red;
            Handles.DrawSolidDisc(new Vector3(markerX, markerY, 0), Vector3.forward, 2f);
        }

        Handles.EndGUI();

        // Y轴标签
        GUIStyle labelStyle = new GUIStyle(EditorStyles.miniLabel);
        labelStyle.normal.textColor = Color.gray;
        labelStyle.fontSize = 9;

        GUI.Label(new Rect(rect.x + 2, rect.y, 50, 12), $"{maxBudget}", labelStyle);
        GUI.Label(new Rect(rect.x + 2, rect.y + rect.height - 12, 30, 12), "0", labelStyle);

        // 目标线
        float burstLineY = rect.y + rect.height - (burstRatio * rect.height);
        float spreadLineY = rect.y + rect.height - (spreadRatio * rect.height);

        Handles.BeginGUI();
        Handles.color = new Color(1f, 0.4f, 0.1f, 0.5f);
        Handles.DrawDottedLine(
            new Vector3(rect.x, burstLineY, 0),
            new Vector3(rect.x + rect.width, burstLineY, 0), 2f);
        
        Handles.color = new Color(0.3f, 0.7f, 1f, 0.5f);
        Handles.DrawDottedLine(
            new Vector3(rect.x, spreadLineY, 0),
            new Vector3(rect.x + rect.width, spreadLineY, 0), 2f);
        Handles.EndGUI();

        // 标签
        labelStyle.normal.textColor = new Color(1f, 0.4f, 0.1f);
        GUI.Label(new Rect(rect.x + rect.width - 45, burstLineY - 6, 45, 12), $"B:{burstTarget}", labelStyle);
        labelStyle.normal.textColor = new Color(0.3f, 0.7f, 1f);
        GUI.Label(new Rect(rect.x + rect.width - 45, spreadLineY - 6, 45, 12), $"S:{spreadTarget}", labelStyle);
    }
}
#endif