using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace ArgosEdgeLab.ReviewApp
{
    internal sealed class DashboardCatalogStatus
    {
        public string schema { get; set; }
        public string updatedUtc { get; set; }
        public string state { get; set; }
        public int includedWafers { get; set; }
    }

    internal sealed class DashboardManifest
    {
        public string schema { get; set; }
        public string createdUtc { get; set; }
        public string outputRoot { get; set; }
        public bool shareImageQueueEnabled { get; set; }
        public string shareImageQueueRoot { get; set; }
        public string shareImageQueueState { get; set; }
        public double defectOverlayOpacity { get; set; }
        public bool xmlExportEnabled { get; set; }
        public string xmlExportState { get; set; }
        public string scanTimestampAuthority { get; set; }
        public List<FilterFieldDefinition> filterableFields { get; set; }
        public List<ScanSession> scanSessions { get; set; }
        public List<HeldAcquisition> heldAcquisitions { get; set; }
    }

    internal sealed class HeldAcquisition
    {
        public string identity { get; set; }
        public string physicalIdentity { get; set; }
        public string lot { get; set; }
        public string scanTimestampLocal { get; set; }
        public string slot { get; set; }
        public string domain { get; set; }
        public string waferId { get; set; }
        public string holdReason { get; set; }
        public string holdDetail { get; set; }
        public string holdSource { get; set; }
        public string scribeQueueState { get; set; }
        public string scribeNextAction { get; set; }
        public string scribeProposalSource { get; set; }
        public string scribeActionability { get; set; }
    }

    internal sealed class HeldDisplayRow
    {
        public string scanTimestampLocal, lot, slot, waferId, domains;
        public string actionability, exactStateOrReason, nextAction, proposalSource, detail;
    }

    internal sealed class FilterFieldDefinition
    {
        public string key { get; set; }
        public string label { get; set; }
        public string scope { get; set; }
    }

    internal sealed class ScanSession
    {
        public string scanId { get; set; }
        public string lot { get; set; }
        public string scanTimestampLocal { get; set; }
        public string timestampProvenance { get; set; }
        public Dictionary<string, string> metadata { get; set; }
        public List<WaferRecord> wafers { get; set; }

        public DateTime ScanTime
        {
            get
            {
                DateTime value;
                if (!DateTime.TryParse(scanTimestampLocal, CultureInfo.InvariantCulture,
                    DateTimeStyles.AllowWhiteSpaces, out value))
                    throw new InvalidDataException("Invalid scan timestamp for " + scanId + ": " + scanTimestampLocal);
                return DateTime.SpecifyKind(value, DateTimeKind.Unspecified);
            }
        }
    }

    internal sealed class ScanVisit
    {
        public string lot;
        public DateTime scanTime;
        public ScanSession front;
        public ScanSession back;

        public IEnumerable<ScanSession> Sessions
        {
            get
            {
                if (front != null) yield return front;
                if (back != null) yield return back;
            }
        }

        public IEnumerable<WaferRecord> Wafers
        {
            get { return Sessions.SelectMany(item => item.wafers ?? new List<WaferRecord>()); }
        }

        public ScanSession SessionForSide(string side)
        {
            if (String.Equals(side, "FRONT", StringComparison.OrdinalIgnoreCase)) return front;
            if (String.Equals(side, "BACK", StringComparison.OrdinalIgnoreCase)) return back;
            return null;
        }
    }

    internal sealed class WaferRecord
    {
        public string identity { get; set; }
        public string lot { get; set; }
        public string waferId { get; set; }
        public string product { get; set; }
        public string processBlock { get; set; }
        public string step { get; set; }
        public string slot { get; set; }
        public string lastTool { get; set; }
        public string backsideBfRaw { get; set; }
        public string backsideBfAccepted { get; set; }
        public string backsideBfConfirmation { get; set; }
        public string backsideBfShadowRaw { get; set; }
        public string backsideBfShadowAccepted { get; set; }
        public string backsideBfShadowConfirmation { get; set; }
        public string backsideDfRaw { get; set; }
        public string backsideCompositeAcceptedBf { get; set; }
        public string backsideCompositeAcceptedDf { get; set; }
        public string backsideCompositeAcceptedDfDisplay { get; set; }
        public int scratchAcceptedBranchComponents { get; set; }
        public int scratchConfirmationBranchComponents { get; set; }
        public string frontsideBfRaw { get; set; }
        public string frontsideDfRaw { get; set; }
        public string frontsideCompositeAcceptedBf { get; set; }
        public string frontsideCompositeAcceptedDf { get; set; }
        public string frontsideCompositeAcceptedDfDisplay { get; set; }
        public Dictionary<string, string> metadata { get; set; }
    }

    internal sealed class DashboardResult
    {
        public string DirectoryPath;
        public string BacksideRawPath;
        public string BacksidePath;
        public string BacksideConfirmationPath;
        public string ShadowRawPath;
        public string ShadowAcceptedPath;
        public string ShadowConfirmationPath;
        public string FrontsidePath;
        public string Lot;
        public DateTime ScanTime;
        public int WaferCount;
        public bool HasFrontside;
        public bool HasFullInspectionReview;
        public bool ShareImageQueueEnabled;
        public string ShareImageQueueRoot;
        public string ShareImageQueueState;
        public string InspectionSide;
    }

    internal static class CatalogContract
    {
        public static void Validate(DashboardManifest manifest)
        {
            if (manifest == null)
                throw new InvalidDataException("Dashboard catalog is empty.");
            if (!String.Equals(manifest.schema, "argos_lot_dashboard_catalog_v4_composite_accepted", StringComparison.Ordinal))
                throw new InvalidDataException("Unsupported dashboard catalog schema: " + manifest.schema);
            if (String.IsNullOrWhiteSpace(manifest.outputRoot))
                throw new InvalidDataException("Dashboard outputRoot is missing.");
            if (manifest.shareImageQueueEnabled && String.IsNullOrWhiteSpace(manifest.shareImageQueueRoot))
                throw new InvalidDataException("Image-sharing queue is enabled but its queue root is missing.");
            if (manifest.xmlExportEnabled)
                throw new InvalidDataException("XML export must remain disabled until defect bins are approved.");
            if (!String.Equals(manifest.xmlExportState,
                "DISABLED_PENDING_DATA_ENGINEERING_DEFECT_BINS_AND_COORDINATE_AUTHORITY", StringComparison.Ordinal))
                throw new InvalidDataException("The required XML-export hold is missing.");
            if (manifest.scanSessions == null) manifest.scanSessions = new List<ScanSession>();
            if (manifest.heldAcquisitions == null) manifest.heldAcquisitions = new List<HeldAcquisition>();
            if (manifest.scanSessions.Count == 0 && manifest.heldAcquisitions.Count == 0)
                throw new InvalidDataException("No completed scan sessions or held acquisitions are cataloged.");

            if (manifest.filterableFields == null || manifest.filterableFields.Count == 0)
                throw new InvalidDataException("The metadata filter-field catalog is missing.");
            HashSet<string> filterKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (FilterFieldDefinition field in manifest.filterableFields)
            {
                if (field == null || String.IsNullOrWhiteSpace(field.key) ||
                    String.IsNullOrWhiteSpace(field.label) || String.IsNullOrWhiteSpace(field.scope))
                    throw new InvalidDataException("Every filter field requires key, label, and scope.");
                if (!filterKeys.Add(field.key))
                    throw new InvalidDataException("Duplicate metadata filter key: " + field.key);
            }

            HashSet<string> scanIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (ScanSession session in manifest.scanSessions)
            {
                if (session == null || String.IsNullOrWhiteSpace(session.scanId) ||
                    String.IsNullOrWhiteSpace(session.lot))
                    throw new InvalidDataException("Every scan session requires scanId and lot.");
                if (!scanIds.Add(session.scanId))
                    throw new InvalidDataException("Duplicate scanId: " + session.scanId);
                DateTime unused = session.ScanTime;
                if (session.wafers == null || session.wafers.Count == 0)
                    throw new InvalidDataException("Scan session contains no wafers: " + session.scanId);

                HashSet<string> identities = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (WaferRecord wafer in session.wafers)
                {
                    if (wafer == null || String.IsNullOrWhiteSpace(wafer.identity) ||
                        String.IsNullOrWhiteSpace(wafer.slot))
                        throw new InvalidDataException("Every wafer requires identity and slot in " + session.scanId);
                    if (!identities.Add(wafer.identity))
                        throw new InvalidDataException("Duplicate wafer identity in " + session.scanId + ": " + wafer.identity);
                    bool frontside = IsFrontsideWafer(wafer);
                    string bfRaw = frontside ? wafer.frontsideBfRaw : wafer.backsideBfRaw;
                    string dfRaw = frontside ? wafer.frontsideDfRaw : wafer.backsideDfRaw;
                    string acceptedBf = frontside ? wafer.frontsideCompositeAcceptedBf : wafer.backsideCompositeAcceptedBf;
                    string acceptedDf = frontside ? wafer.frontsideCompositeAcceptedDf : wafer.backsideCompositeAcceptedDf;
                    string acceptedDfDisplay = frontside ? wafer.frontsideCompositeAcceptedDfDisplay : wafer.backsideCompositeAcceptedDfDisplay;
                    if (String.IsNullOrWhiteSpace(bfRaw) || !File.Exists(bfRaw) ||
                        String.IsNullOrWhiteSpace(dfRaw) || !File.Exists(dfRaw) ||
                        String.IsNullOrWhiteSpace(acceptedBf) || !File.Exists(acceptedBf) ||
                        String.IsNullOrWhiteSpace(acceptedDf) || !File.Exists(acceptedDf) ||
                        String.IsNullOrWhiteSpace(acceptedDfDisplay) || !File.Exists(acceptedDfDisplay))
                        throw new InvalidDataException((frontside ? "Frontside" : "Backside") +
                            " composite accepted BF/DF review artifacts are incomplete for " + wafer.identity);
                }

                bool anyFrontside = session.wafers.Any(IsFrontsideWafer);
                if (anyFrontside && !session.wafers.All(IsFrontsideWafer))
                    throw new InvalidDataException("A scan session may not mix frontside and backside wafers: " + session.scanId);
            }
            HashSet<string> heldIdentities = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (HeldAcquisition held in manifest.heldAcquisitions)
            {
                if (held == null || String.IsNullOrWhiteSpace(held.identity) ||
                    String.IsNullOrWhiteSpace(held.holdReason))
                    throw new InvalidDataException("Every held acquisition requires identity and exact hold reason.");
                if (!heldIdentities.Add(held.identity))
                    throw new InvalidDataException("Duplicate held acquisition identity: " + held.identity);
            }
        }

        private static bool IsFrontsideWafer(WaferRecord wafer)
        {
            string domain;
            return wafer != null && wafer.metadata != null &&
                wafer.metadata.TryGetValue("domain", out domain) &&
                String.Equals(domain, "FRONTSIDE", StringComparison.OrdinalIgnoreCase);
        }
    }

    internal static class ScanSessionQuery
    {
        private static List<ScanVisit> BuildVisits(IEnumerable<ScanSession> sessions)
        {
            List<ScanVisit> visits = new List<ScanVisit>();
            IEnumerable<IGrouping<string, ScanSession>> groups = sessions
                .GroupBy(item => (item.lot ?? String.Empty).Trim().ToUpperInvariant() + "\u001f" +
                    item.ScanTime.Ticks.ToString(CultureInfo.InvariantCulture));
            foreach (IGrouping<string, ScanSession> group in groups)
            {
                List<ScanSession> front = group.Where(item =>
                    String.Equals(InspectionSide(item), "FRONT", StringComparison.Ordinal)).ToList();
                List<ScanSession> back = group.Where(item =>
                    String.Equals(InspectionSide(item), "BACK", StringComparison.Ordinal)).ToList();
                ScanSession first = group.First();
                if (front.Count > 1 || back.Count > 1)
                    throw new InvalidDataException("A lot/timestamp visit contains duplicate same-side results: " +
                        first.lot + " " + first.ScanTime.ToString("yyyy-MM-dd HH:mm:ss"));
                visits.Add(new ScanVisit {
                    lot = first.lot,
                    scanTime = first.ScanTime,
                    front = front.SingleOrDefault(),
                    back = back.SingleOrDefault()
                });
            }
            return visits.OrderByDescending(item => item.scanTime).ThenBy(item => item.lot).ToList();
        }

        public static List<ScanVisit> VisitsForDate(IEnumerable<ScanSession> sessions, DateTime date)
        {
            return BuildVisits(sessions.Where(item => item.ScanTime.Date == date.Date));
        }

        public static List<ScanVisit> VisitsForAllDates(IEnumerable<ScanSession> sessions)
        {
            return BuildVisits(sessions);
        }

        public static void AssertRepeatedLotVisitsRemainDistinct()
        {
            WaferRecord frontA = new WaferRecord { identity="FA", slot="Slot01",
                metadata=new Dictionary<string,string>{{"domain","FRONTSIDE"}} };
            WaferRecord backA = new WaferRecord { identity="BA", slot="Slot01",
                metadata=new Dictionary<string,string>{{"domain","BACKSIDE"}} };
            WaferRecord frontB = new WaferRecord { identity="FB", slot="Slot01",
                metadata=new Dictionary<string,string>{{"domain","FRONTSIDE"}} };
            WaferRecord backB = new WaferRecord { identity="BB", slot="Slot01",
                metadata=new Dictionary<string,string>{{"domain","BACKSIDE"}} };
            List<ScanSession> fixture = new List<ScanSession> {
                new ScanSession { scanId="LOT-A_FRONT_0800", lot="LOT-A", scanTimestampLocal="2026-08-05T08:00:00", wafers=new List<WaferRecord>{frontA} },
                new ScanSession { scanId="LOT-A_BACK_0800", lot="LOT-A", scanTimestampLocal="2026-08-05T08:00:00", wafers=new List<WaferRecord>{backA} },
                new ScanSession { scanId="LOT-A_FRONT_1600", lot="LOT-A", scanTimestampLocal="2026-08-05T16:00:00", wafers=new List<WaferRecord>{frontB} },
                new ScanSession { scanId="LOT-A_BACK_1600", lot="LOT-A", scanTimestampLocal="2026-08-05T16:00:00", wafers=new List<WaferRecord>{backB} }
            };
            List<ScanVisit> result = VisitsForDate(fixture, new DateTime(2026, 8, 5));
            if (result.Count != 2 || result[0].scanTime <= result[1].scanTime ||
                result.Any(item => item.front == null || item.back == null))
                throw new InvalidOperationException("Two same-day visits were not grouped into two FRONT/BACK rows.");
        }

        public static string InspectionSide(ScanSession session)
        {
            if (session == null || session.wafers == null || session.wafers.Count == 0)
                throw new InvalidDataException("A selectable inspection result must contain wafers.");
            bool anyFrontside = session.wafers.Any(IsFrontsideWafer);
            bool allFrontside = session.wafers.All(IsFrontsideWafer);
            if (anyFrontside && !allFrontside)
                throw new InvalidDataException("A selectable result may not mix FRONT and BACK: " + session.scanId);
            return allFrontside ? "FRONT" : "BACK";
        }

        public static void AssertInspectionSideLabels()
        {
            WaferRecord front = new WaferRecord { identity="F", slot="Slot01",
                metadata=new Dictionary<string,string>{{"domain","FRONTSIDE"}} };
            WaferRecord back = new WaferRecord { identity="B", slot="Slot01",
                metadata=new Dictionary<string,string>{{"domain","BACKSIDE"}} };
            ScanSession frontSession = new ScanSession { scanId="FRONT_TEST", lot="LOT-A",
                scanTimestampLocal="2026-08-05T08:00:00", wafers=new List<WaferRecord>{front} };
            ScanSession backSession = new ScanSession { scanId="BACK_TEST", lot="LOT-A",
                scanTimestampLocal="2026-08-05T08:00:00", wafers=new List<WaferRecord>{back} };
            if (!String.Equals(InspectionSide(frontSession), "FRONT", StringComparison.Ordinal) ||
                !String.Equals(InspectionSide(backSession), "BACK", StringComparison.Ordinal))
                throw new InvalidOperationException("FRONT/BACK selector-label regression failed.");
            bool mixedHeld = false;
            try
            {
                InspectionSide(new ScanSession { scanId="MIXED_TEST", lot="LOT-A",
                    scanTimestampLocal="2026-08-05T08:00:00", wafers=new List<WaferRecord>{front,back} });
            }
            catch (InvalidDataException) { mixedHeld = true; }
            if (!mixedHeld)
                throw new InvalidOperationException("Mixed-side selector regression failed.");
        }

        private static bool IsFrontsideWafer(WaferRecord wafer)
        {
            string domain;
            return wafer != null && wafer.metadata != null &&
                wafer.metadata.TryGetValue("domain", out domain) &&
                String.Equals(domain, "FRONTSIDE", StringComparison.OrdinalIgnoreCase);
        }
    }

    internal static class DashboardGenerator
    {
        private const int CellWidth = 1000;
        private const int CellHeight = 850;
        private const int CellHeaderHeight = 154;
        private const int DashboardHeaderHeight = 92;
        private const int MaximumColumns = 5;

        public static DashboardResult Generate(DashboardManifest manifest, ScanSession session,
            double displayOverlayOpacity)
        {
            CatalogContract.Validate(manifest);
            if (session == null || session.wafers == null || session.wafers.Count == 0)
                throw new InvalidOperationException("Select a scan session containing at least one wafer.");
            if (!manifest.scanSessions.Any(item => String.Equals(item.scanId, session.scanId,
                StringComparison.OrdinalIgnoreCase)))
                throw new InvalidOperationException("The selected scan is not in the current catalog.");
            if (displayOverlayOpacity < 0.05 || displayOverlayOpacity > 1.0)
                throw new InvalidOperationException("Display overlay visibility must be between 5% and 100%.");

            string stamp = DateTime.UtcNow.ToString("yyyyMMddTHHmmssZ");
            string scanStamp = session.ScanTime.ToString("yyyyMMddTHHmmss");
            string sideToken = ScanSessionQuery.InspectionSide(session);
            string outputName = "R_" + SafeToken(session.lot) + "_" + scanStamp + "_" +
                sideToken + "_" + stamp;
            string output = Path.Combine(manifest.outputRoot, outputName);
            if (Directory.Exists(output) || File.Exists(output))
                throw new IOException("Refusing to overwrite dashboard output: " + output);
            Directory.CreateDirectory(output);

            bool anyFrontsideInspection = session.wafers.Any(IsFrontsideWafer);
            bool isFrontsideInspection = session.wafers.All(IsFrontsideWafer);
            if (anyFrontsideInspection && !isFrontsideInspection)
                throw new InvalidDataException("The selected scan mixes frontside and backside records and cannot be opened: " + session.scanId);
            bool hasFullInspectionReview = session.wafers.All(item =>
                File.Exists(BasePath(item, "COMPOSITE_ACCEPTED_BF")) &&
                File.Exists(BasePath(item, "COMPOSITE_ACCEPTED_DF_ENHANCED")) &&
                File.Exists(BasePath(item, "COMPOSITE_ACCEPTED_DF_EXACT")));
            if (!hasFullInspectionReview)
                throw new InvalidDataException("The selected scan lacks the required composite accepted BF/DF evidence.");
            string back = Path.Combine(output, "COMPOSITE_ACCEPTED_BF.png");
            string shadowAccepted = Path.Combine(output, "COMPOSITE_ACCEPTED_DF_ENHANCED_DISPLAY_ONLY.png");
            string backRaw = null;
            string backConfirmation = null;
            string shadowRaw = Path.Combine(output, "COMPOSITE_ACCEPTED_DF_UNTOUCHED.png");
            string shadowConfirmation = null;
            bool hasFrontside = !isFrontsideInspection && session.wafers.Any(item =>
                !String.IsNullOrWhiteSpace(item.frontsideBfRaw) && File.Exists(item.frontsideBfRaw));
            string front = hasFrontside
                ? Path.Combine(output, "FRONTSIDE_BF_LOT_DASHBOARD.png")
                : null;
            BuildSide(manifest, session, "COMPOSITE_ACCEPTED_BF", 1.0, back);
            BuildSide(manifest, session, "COMPOSITE_ACCEPTED_DF_ENHANCED", 1.0, shadowAccepted);
            BuildSide(manifest, session, "COMPOSITE_ACCEPTED_DF_EXACT", 1.0, shadowRaw);
            if (hasFrontside)
                BuildSide(manifest, session, "FRONTSIDE_BF", displayOverlayOpacity, front);

            File.WriteAllText(Path.Combine(output, "DASHBOARD_GENERATION.txt"),
                "Generated UTC: " + DateTime.UtcNow.ToString("o") + Environment.NewLine +
                "Lot: " + session.lot + Environment.NewLine +
                "Scan ID: " + session.scanId + Environment.NewLine +
                "Scan timestamp (tool local): " + session.ScanTime.ToString("yyyy-MM-dd HH:mm:ss") + Environment.NewLine +
                "Timestamp provenance: " + session.timestampProvenance + Environment.NewLine +
                "Wafer count: " + session.wafers.Count + Environment.NewLine +
                "Composite accepted display opacity: 1.00" + Environment.NewLine +
                "Composite contract: per-class native-pixel OR of raw accepted and shadow accepted evidence." + Environment.NewLine +
                "Views: the same composite accepted class masks rendered over BF and DF." + Environment.NewLine +
                "DF display: accepted-mask colors strengthened on unchanged raw DF; display only, support pixels unchanged." + Environment.NewLine +
                "Scratch confirmation holds are excluded from the composite accepted result and future reject bins." + Environment.NewLine +
                "Display-only control: true; detector masks, counts, classes, and decisions unchanged." + Environment.NewLine +
                "Inspection side: " + (isFrontsideInspection ? "FRONTSIDE" : "BACKSIDE") + Environment.NewLine +
                "Frontside review: " + (isFrontsideInspection
                    ? "explicit frontside composite accepted BF/DF fields; no backside artifact alias was used by the popup."
                    : (hasFrontside ? "separate raw display overview present."
                        : "not present in this backside-only scan; no frontside image or tab was invented.")) + Environment.NewLine +
                "Inputs are display overviews only. Native detector sources remain unchanged." + Environment.NewLine +
                "XML export: DISABLED_PENDING_DATA_ENGINEERING_DEFECT_BINS_AND_COORDINATE_AUTHORITY" + Environment.NewLine +
                "Review only: true" + Environment.NewLine);

            return new DashboardResult {
                DirectoryPath = output,
                BacksideRawPath = backRaw,
                BacksidePath = back,
                BacksideConfirmationPath = backConfirmation,
                ShadowRawPath = shadowRaw,
                ShadowAcceptedPath = shadowAccepted,
                ShadowConfirmationPath = shadowConfirmation,
                FrontsidePath = front,
                Lot = session.lot,
                ScanTime = session.ScanTime,
                WaferCount = session.wafers.Count,
                HasFrontside = hasFrontside,
                HasFullInspectionReview = hasFullInspectionReview,
                ShareImageQueueEnabled = manifest.shareImageQueueEnabled,
                ShareImageQueueRoot = manifest.shareImageQueueRoot,
                ShareImageQueueState = manifest.shareImageQueueState,
                InspectionSide = sideToken
            };
        }

        private static void BuildSide(DashboardManifest manifest, ScanSession session,
            string viewKey, double displayOverlayOpacity, string outputPath)
        {
            List<WaferRecord> wafers = session.wafers
                .OrderBy(item => SlotOrder(item.slot)).ThenBy(item => item.identity).ToList();
            bool frontside = String.Equals(viewKey, "FRONTSIDE_BF", StringComparison.Ordinal) ||
                wafers.All(IsFrontsideWafer);
            int columns = Math.Min(MaximumColumns, Math.Max(1, wafers.Count));
            int rows = (wafers.Count + columns - 1) / columns;
            int canvasWidth = columns * CellWidth;
            int canvasHeight = DashboardHeaderHeight + rows * CellHeight;

            using (Bitmap canvas = new Bitmap(canvasWidth, canvasHeight, PixelFormat.Format24bppRgb))
            using (Graphics g = Graphics.FromImage(canvas))
            using (Font dashboardTitle = new Font("Segoe UI", 22, FontStyle.Bold))
            using (Font dashboardValue = new Font("Segoe UI", 13, FontStyle.Regular))
            using (Font titleFont = new Font("Segoe UI", 17, FontStyle.Bold))
            using (Font labelFont = new Font("Segoe UI", 11, FontStyle.Bold))
            using (Font valueFont = new Font("Segoe UI", 10, FontStyle.Regular))
            using (Brush titleBrush = new SolidBrush(Color.White))
            using (Brush subtitleBrush = new SolidBrush(Color.FromArgb(196, 219, 228)))
            {
                g.Clear(Color.FromArgb(8, 11, 14));
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g.SmoothingMode = SmoothingMode.HighQuality;

                string sideName = ViewTitle(viewKey, frontside);
                g.DrawString("Lot " + session.lot + "  |  " + sideName,
                    dashboardTitle, titleBrush, 20, 10);
                string visibility = ViewLegend(viewKey, displayOverlayOpacity);
                g.DrawString("Scan " + session.ScanTime.ToString("yyyy-MM-dd HH:mm:ss") +
                    " tool local  |  " + wafers.Count + " wafers  |  " + visibility + "  |  Review only",
                    dashboardValue, subtitleBrush, 22, 52);

                for (int i = 0; i < wafers.Count; i++)
                {
                    int col = i % columns;
                    int row = i / columns;
                    Rectangle cell = new Rectangle(col * CellWidth,
                        DashboardHeaderHeight + row * CellHeight, CellWidth, CellHeight);
                    DrawCell(g, cell, wafers[i], viewKey, frontside,
                        (float)displayOverlayOpacity, titleFont, labelFont, valueFont);
                }
                canvas.Save(outputPath, ImageFormat.Png);
            }
        }

        private static void DrawCell(Graphics g, Rectangle cell, WaferRecord wafer, string viewKey,
            bool frontside, float overlayOpacity, Font titleFont, Font labelFont, Font valueFont)
        {
            using (Pen border = new Pen(Color.FromArgb(60, 116, 134), 2))
            using (Brush header = new SolidBrush(Color.FromArgb(19, 27, 32)))
            using (Brush titleBrush = new SolidBrush(Color.White))
            using (Brush valueBrush = new SolidBrush(Color.FromArgb(210, 225, 231)))
            {
                g.FillRectangle(Brushes.Black, cell);
                g.DrawRectangle(border, cell.X, cell.Y, cell.Width - 1, cell.Height - 1);
                Rectangle headerRect = new Rectangle(cell.X + 2, cell.Y + 2,
                    cell.Width - 4, CellHeaderHeight - 2);
                g.FillRectangle(header, headerRect);

                string operatorWaferIdentity = String.IsNullOrWhiteSpace(wafer.waferId)
                    ? "WAFER IDENTITY HOLD"
                    : wafer.waferId.Trim();
                g.DrawString(operatorWaferIdentity + (frontside ? "  FRONT" : "  BACK"),
                    titleFont, titleBrush, cell.X + 14, cell.Y + 9);
                string line1 = "Lot: " + (wafer.lot ?? "") + "    Product: " + wafer.product;
                string line2 = "Slot: " + wafer.slot + "    Process: " + wafer.processBlock;
                string line3 = "Step: " + wafer.step;
                string line4 = "Last Tool: " + wafer.lastTool;
                g.DrawString(line1, labelFont, valueBrush, cell.X + 16, cell.Y + 47);
                g.DrawString(line2, valueFont, valueBrush, cell.X + 16, cell.Y + 76);
                g.DrawString(line3, valueFont, valueBrush, cell.X + 16, cell.Y + 101);
                g.DrawString(line4, valueFont, valueBrush, cell.X + 16, cell.Y + 126);

                Rectangle imageRect = new Rectangle(cell.X + 8, cell.Y + CellHeaderHeight + 8,
                    cell.Width - 16, cell.Height - CellHeaderHeight - 16);
                string rawPath = BasePath(wafer, viewKey);
                if (!File.Exists(rawPath))
                    throw new FileNotFoundException("Dashboard image was not found.", rawPath);

                using (Image raw = Image.FromFile(rawPath))
                {
                    Rectangle fit = Fit(raw.Size, imageRect);
                    g.DrawImage(raw, fit);
                    string overlayPath = OverlayPath(wafer, viewKey);
                    if (!String.IsNullOrWhiteSpace(overlayPath) && File.Exists(overlayPath))
                    {
                        using (Image accepted = Image.FromFile(overlayPath))
                        using (ImageAttributes attrs = new ImageAttributes())
                        {
                            ColorMatrix cm = new ColorMatrix();
                            cm.Matrix33 = Math.Max(0.05f, Math.Min(1.00f, overlayOpacity));
                            attrs.SetColorMatrix(cm, ColorMatrixFlag.Default, ColorAdjustType.Bitmap);
                            g.DrawImage(accepted, fit, 0, 0, accepted.Width, accepted.Height,
                                GraphicsUnit.Pixel, attrs);
                        }
                    }
                }
            }
        }

        private static string BasePath(WaferRecord wafer, string viewKey)
        {
            if (String.Equals(viewKey, "FRONTSIDE_BF", StringComparison.Ordinal))
                return wafer.frontsideBfRaw;
            if (String.Equals(viewKey, "COMPOSITE_ACCEPTED_BF", StringComparison.Ordinal))
                return IsFrontsideWafer(wafer) ? wafer.frontsideCompositeAcceptedBf : wafer.backsideCompositeAcceptedBf;
            if (String.Equals(viewKey, "COMPOSITE_ACCEPTED_DF_ENHANCED", StringComparison.Ordinal))
                return IsFrontsideWafer(wafer) ? wafer.frontsideCompositeAcceptedDfDisplay : wafer.backsideCompositeAcceptedDfDisplay;
            if (String.Equals(viewKey, "COMPOSITE_ACCEPTED_DF_EXACT", StringComparison.Ordinal))
                return IsFrontsideWafer(wafer) ? wafer.frontsideCompositeAcceptedDf : wafer.backsideCompositeAcceptedDf;
            if (viewKey.StartsWith("SHADOW_", StringComparison.Ordinal))
                return wafer.backsideBfShadowRaw;
            return wafer.backsideBfRaw;
        }

        private static string OverlayPath(WaferRecord wafer, string viewKey)
        {
            switch (viewKey)
            {
                case "COMPOSITE_ACCEPTED_BF": return null;
                case "COMPOSITE_ACCEPTED_DF": return null;
                case "RAW_ACCEPTED": return wafer.backsideBfAccepted;
                case "RAW_CONFIRMATION": return wafer.backsideBfConfirmation;
                case "SHADOW_ACCEPTED": return wafer.backsideBfShadowAccepted;
                case "SHADOW_CONFIRMATION": return wafer.backsideBfShadowConfirmation;
                case "LEGACY_BACKSIDE": return wafer.backsideBfAccepted;
                default: return null;
            }
        }

        private static bool IsFrontsideWafer(WaferRecord wafer)
        {
            string domain;
            return wafer != null && wafer.metadata != null &&
                wafer.metadata.TryGetValue("domain", out domain) &&
                String.Equals(domain, "FRONTSIDE", StringComparison.OrdinalIgnoreCase);
        }

        private static string ViewTitle(string viewKey, bool frontside)
        {
            switch (viewKey)
            {
                case "COMPOSITE_ACCEPTED_BF": return (frontside ? "FRONTSIDE" : "BACKSIDE") + " BF - COMPOSITE ACCEPTED DEFECTS";
                case "COMPOSITE_ACCEPTED_DF_ENHANCED": return (frontside ? "FRONTSIDE" : "BACKSIDE") + " DF - COMPOSITE ACCEPTED (ENHANCED DISPLAY)";
                case "COMPOSITE_ACCEPTED_DF_EXACT": return (frontside ? "FRONTSIDE" : "BACKSIDE") + " DF - COMPOSITE ACCEPTED (UNTOUCHED)";
                case "RAW_BF": return "BACKSIDE RAW BF";
                case "RAW_ACCEPTED": return "BACKSIDE RAW ACCEPTED DEFECTS";
                case "RAW_CONFIRMATION": return "BACKSIDE RAW SCRATCH CONFIRMATION HOLDS";
                case "SHADOW_BF": return "BACKSIDE SHADOW BF";
                case "SHADOW_ACCEPTED": return "BACKSIDE SHADOW ACCEPTED DEFECTS";
                case "SHADOW_CONFIRMATION": return "BACKSIDE SHADOW SCRATCH CONFIRMATION HOLDS";
                case "FRONTSIDE_BF": return "FRONTSIDE BF";
                default: return "BACKSIDE BF";
            }
        }

        private static string ViewLegend(string viewKey, double opacity)
        {
            if (String.Equals(viewKey, "COMPOSITE_ACCEPTED_DF_ENHANCED", StringComparison.Ordinal))
                return "same accepted pixels; gamma 0.35 display-only";
            if (String.Equals(viewKey, "COMPOSITE_ACCEPTED_DF_EXACT", StringComparison.Ordinal))
                return "untouched DF composite accepted overview; audit display";
            if (viewKey.StartsWith("COMPOSITE_ACCEPTED_", StringComparison.Ordinal))
                return "raw accepted OR shadow accepted, confirmation holds excluded, display 100%";
            if (viewKey.EndsWith("_CONFIRMATION", StringComparison.Ordinal))
                return "cyan = Scratch confirmation HOLD, not automatic reject";
            if (viewKey.EndsWith("_ACCEPTED", StringComparison.Ordinal) ||
                String.Equals(viewKey, "LEGACY_BACKSIDE", StringComparison.Ordinal))
                return "accepted masks only, confirmation holds excluded, display " +
                    Math.Round(opacity * 100.0).ToString("0") + "%";
            return "raw display, no mask overlay";
        }

        private static int SlotOrder(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return Int32.MaxValue;
            string digits = new String(value.Where(Char.IsDigit).ToArray());
            int number;
            return Int32.TryParse(digits, out number) ? number : Int32.MaxValue;
        }

        private static string SafeToken(string value)
        {
            char[] invalid = Path.GetInvalidFileNameChars();
            return new String((value ?? "UNKNOWN").Select(ch => invalid.Contains(ch) ? '_' : ch).ToArray());
        }

        private static Rectangle Fit(Size source, Rectangle target)
        {
            double scale = Math.Min(target.Width / (double)source.Width,
                target.Height / (double)source.Height);
            int width = Math.Max(1, (int)Math.Round(source.Width * scale));
            int height = Math.Max(1, (int)Math.Round(source.Height * scale));
            return new Rectangle(target.X + (target.Width - width) / 2,
                target.Y + (target.Height - height) / 2, width, height);
        }
    }

    internal sealed class DashboardWindow : Form
    {
        private readonly DashboardResult result;
        private readonly TabControl tabs;
        private readonly Label imageDetails;

        internal int ReviewTabCount { get { return tabs.TabPages.Count; } }

        internal string[] ReviewTabTitles
        {
            get { return tabs.TabPages.Cast<TabPage>().Select(page => page.Text).ToArray(); }
        }

        public DashboardWindow(DashboardResult result)
        {
            this.result = result;
            Text = "Argos Lot " + result.Lot + " - " +
                result.ScanTime.ToString("yyyy-MM-dd HH:mm:ss");
            Width = 1500;
            Height = 950;
            BackColor = Color.FromArgb(12, 16, 19);

            Panel toolbar = new Panel {
                Dock = DockStyle.Top, Height = 52, BackColor = Color.FromArgb(22, 30, 35)
            };
            Button export = new Button {
                Text = "Save Current Image...", Left = 12, Top = 10, Width = 180, Height = 32,
                BackColor = Color.FromArgb(25, 113, 164), ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat, UseVisualStyleBackColor = false,
                Font = new Font("Segoe UI", 9, FontStyle.Bold)
            };
            Button queue = new Button {
                Text = "Queue Image for Sharing", Left = 202, Top = 10, Width = 190, Height = 32,
                BackColor = Color.FromArgb(31, 122, 82), ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat, UseVisualStyleBackColor = false,
                Font = new Font("Segoe UI", 9, FontStyle.Bold),
                Enabled = result.ShareImageQueueEnabled
            };
            Button openFolder = new Button {
                Text = "Open Output Folder", Left = 402, Top = 10, Width = 165, Height = 32,
                BackColor = Color.FromArgb(45, 57, 65), ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat, UseVisualStyleBackColor = false,
                Font = new Font("Segoe UI", 9, FontStyle.Bold)
            };
            export.FlatAppearance.BorderColor = Color.FromArgb(110, 205, 255);
            queue.FlatAppearance.BorderColor = Color.FromArgb(118, 231, 174);
            openFolder.FlatAppearance.BorderColor = Color.FromArgb(170, 187, 196);
            imageDetails = new Label {
                Left = 585, Top = 14, Width = 760, Height = 26,
                ForeColor = Color.White, AutoEllipsis = true
            };
            export.Click += ExportCurrentImage;
            queue.Click += QueueCurrentImage;
            openFolder.Click += delegate { Process.Start(result.DirectoryPath); };
            toolbar.Controls.Add(export);
            toolbar.Controls.Add(queue);
            toolbar.Controls.Add(openFolder);
            toolbar.Controls.Add(imageDetails);

            tabs = new TabControl { Dock = DockStyle.Fill };
            if (result.HasFullInspectionReview)
            {
                tabs.TabPages.Add(BuildPage("Composite Accepted BF", result.BacksidePath));
                tabs.TabPages.Add(BuildDfPage(result.ShadowAcceptedPath, result.ShadowRawPath));
            }
            else
            {
                tabs.TabPages.Add(BuildPage("Backside BF", result.BacksidePath));
            }
            if (result.HasFrontside)
                tabs.TabPages.Add(BuildPage("Frontside BF", result.FrontsidePath));
            tabs.SelectedIndexChanged += delegate { UpdateImageDetails(); };
            tabs.SelectedIndex = 0;
            Controls.Add(tabs);
            Controls.Add(toolbar);
            UpdateImageDetails(result.BacksidePath);
        }

        private static TabPage BuildPage(string title, string path)
        {
            TabPage page = new TabPage(title) { Tag = path };
            Panel scroll = new Panel { Dock = DockStyle.Fill, AutoScroll = true, BackColor = Color.Black };
            PictureBox picture = new PictureBox {
                Image = Image.FromFile(path), SizeMode = PictureBoxSizeMode.AutoSize
            };
            picture.DoubleClick += delegate { Process.Start(path); };
            scroll.Controls.Add(picture);
            page.Controls.Add(scroll);
            return page;
        }

        private TabPage BuildDfPage(string enhancedPath, string untouchedPath)
        {
            TabPage page = new TabPage("Composite Accepted DF") { Tag = enhancedPath };
            Panel root = new Panel { Dock = DockStyle.Fill, BackColor = Color.Black };
            Panel modeBar = new Panel {
                Dock = DockStyle.Top, Height = 44, BackColor = Color.FromArgb(19, 27, 32)
            };
            Label mode = new Label {
                Left = 14, Top = 12, Width = 720, Height = 24,
                ForeColor = Color.White,
                Text = "Enhanced DF - human/share display only (detector and XML inputs unchanged)"
            };
            Button toggle = new Button {
                Left = 755, Top = 7, Width = 210, Height = 30,
                Text = "Show Untouched DF",
                BackColor = Color.FromArgb(45, 57, 65), ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat, UseVisualStyleBackColor = false,
                Font = new Font("Segoe UI", 9, FontStyle.Bold)
            };
            toggle.FlatAppearance.BorderColor = Color.FromArgb(170, 187, 196);
            Panel scroll = new Panel {
                Dock = DockStyle.Fill, AutoScroll = true, BackColor = Color.Black
            };
            PictureBox picture = new PictureBox {
                Image = Image.FromFile(enhancedPath), SizeMode = PictureBoxSizeMode.AutoSize
            };
            bool showingEnhanced = true;
            Action<string> show = delegate(string path) {
                Image replacement = Image.FromFile(path);
                Image previous = picture.Image;
                picture.Image = replacement;
                page.Tag = path;
                if (previous != null) previous.Dispose();
                UpdateImageDetails();
            };
            toggle.Click += delegate {
                showingEnhanced = !showingEnhanced;
                if (showingEnhanced)
                {
                    show(enhancedPath);
                    mode.Text = "Enhanced DF - human/share display only (detector and XML inputs unchanged)";
                    toggle.Text = "Show Untouched DF";
                }
                else
                {
                    show(untouchedPath);
                    mode.Text = "Untouched DF composite accepted overview - audit display";
                    toggle.Text = "Show Enhanced DF";
                }
            };
            picture.DoubleClick += delegate { Process.Start((string)page.Tag); };
            page.Disposed += delegate { if (picture.Image != null) picture.Image.Dispose(); };
            scroll.Controls.Add(picture);
            modeBar.Controls.Add(mode);
            modeBar.Controls.Add(toggle);
            root.Controls.Add(scroll);
            root.Controls.Add(modeBar);
            page.Controls.Add(root);
            return page;
        }

        private string SelectedImagePath()
        {
            if (tabs.SelectedTab == null || !(tabs.SelectedTab.Tag is string))
                throw new InvalidOperationException("No dashboard image is selected.");
            string path = (string)tabs.SelectedTab.Tag;
            if (!File.Exists(path))
                throw new FileNotFoundException("Dashboard image was not found.", path);
            return path;
        }

        private void UpdateImageDetails(string fallbackPath = null)
        {
            try
            {
                string path = fallbackPath;
                if (tabs.SelectedTab != null && tabs.SelectedTab.Tag is string)
                    path = (string)tabs.SelectedTab.Tag;
                if (String.IsNullOrWhiteSpace(path) || !File.Exists(path))
                    throw new FileNotFoundException("Dashboard image was not found.", path);
                using (Image image = Image.FromFile(path))
                {
                    imageDetails.Text = image.Width + " x " + image.Height +
                        " lossless PNG  |  " + Path.GetFileName(path);
                }
            }
            catch (Exception ex)
            {
                imageDetails.Text = "Image unavailable: " + ex.Message;
            }
        }

        private void ExportCurrentImage(object sender, EventArgs e)
        {
            try
            {
                string source = SelectedImagePath();
                string side = SelectedSide();
                using (SaveFileDialog dialog = new SaveFileDialog())
                {
                    dialog.Title = "Export current lot dashboard image";
                    dialog.Filter = "PNG image (*.png)|*.png";
                    dialog.DefaultExt = "png";
                    dialog.AddExtension = true;
                    dialog.OverwritePrompt = true;
                    dialog.FileName = SafeFileToken(result.Lot) + "_" +
                        result.ScanTime.ToString("yyyyMMdd_HHmmss") + "_" + side +
                        "_LOT_DASHBOARD.png";
                    if (dialog.ShowDialog(this) != DialogResult.OK)
                        return;

                    string target = Path.GetFullPath(dialog.FileName);
                    if (!String.Equals(Path.GetFullPath(source), target,
                        StringComparison.OrdinalIgnoreCase))
                        VerifiedFileCopy.Copy(source, target, true);

                    using (Image image = Image.FromFile(target))
                    {
                        MessageBox.Show(this,
                            "Exported a byte-identical lossless PNG." + Environment.NewLine +
                            image.Width + " x " + image.Height + Environment.NewLine + target,
                            "Lot dashboard exported", MessageBoxButtons.OK,
                            MessageBoxIcon.Information);
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.ToString(), "Image export failed",
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void QueueCurrentImage(object sender, EventArgs e)
        {
            try
            {
                if (!result.ShareImageQueueEnabled)
                    throw new InvalidOperationException("The image-sharing queue is not enabled.");
                string source = SelectedImagePath();
                string side = SelectedSide();
                ShareQueueReceipt receipt = ShareImageQueue.Enqueue(source,
                    result.ShareImageQueueRoot, result.Lot, result.ScanTime,
                    result.WaferCount, side, result.ShareImageQueueState);
                MessageBox.Show(this,
                    "Queued the full-resolution lossless PNG for sharing." + Environment.NewLine +
                    receipt.Width + " x " + receipt.Height + "  |  " + receipt.Bytes + " bytes" +
                    Environment.NewLine + receipt.ReadyPackage + Environment.NewLine + Environment.NewLine +
                    "Current relay state: " + result.ShareImageQueueState,
                    "Image queued for sharing", MessageBoxButtons.OK,
                    MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.ToString(), "Image queue failed",
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private static string SafeFileToken(string value)
        {
            char[] invalid = Path.GetInvalidFileNameChars();
            return new string((value ?? "LOT").Select(ch => invalid.Contains(ch) ? '_' : ch).ToArray());
        }

        internal static string ExportSideToken(string inspectionSide, string tabTitle,
            string selectedImagePath)
        {
            string authority = (inspectionSide ?? String.Empty).Trim().ToUpperInvariant();
            string canonicalSide;
            if (authority == "FRONT" || authority == "FRONTSIDE")
                canonicalSide = "FRONTSIDE";
            else if (authority == "BACK" || authority == "BACKSIDE")
                canonicalSide = "BACKSIDE";
            else
                throw new InvalidDataException("Inspection-side authority is missing or invalid: " +
                    inspectionSide);

            string value = new string((tabTitle ?? String.Empty).ToUpperInvariant()
                .Select(ch => Char.IsLetterOrDigit(ch) ? ch : '_').ToArray());
            if (String.IsNullOrWhiteSpace(value)) value = "BF";
            string side = value.StartsWith("FRONTSIDE", StringComparison.Ordinal) ||
                value.StartsWith("BACKSIDE", StringComparison.Ordinal)
                ? value : canonicalSide + "_" + value;
            string selectedName = Path.GetFileName(selectedImagePath ?? String.Empty);
            if (selectedName.IndexOf("UNTOUCHED", StringComparison.OrdinalIgnoreCase) >= 0)
                side += "_UNTOUCHED";
            else if (selectedName.IndexOf("ENHANCED", StringComparison.OrdinalIgnoreCase) >= 0)
                side += "_ENHANCED_DISPLAY_ONLY";
            return side;
        }

        internal static void AssertExportSideNameContract()
        {
            Dictionary<string, string> cases = new Dictionary<string, string> {
                { ExportSideToken("FRONT", "Composite Accepted BF", "COMPOSITE_ACCEPTED_BF.png"),
                    "FRONTSIDE_COMPOSITE_ACCEPTED_BF" },
                { ExportSideToken("FRONT", "Composite Accepted DF", "COMPOSITE_ACCEPTED_DF_ENHANCED_DISPLAY_ONLY.png"),
                    "FRONTSIDE_COMPOSITE_ACCEPTED_DF_ENHANCED_DISPLAY_ONLY" },
                { ExportSideToken("FRONT", "Composite Accepted DF", "COMPOSITE_ACCEPTED_DF_UNTOUCHED.png"),
                    "FRONTSIDE_COMPOSITE_ACCEPTED_DF_UNTOUCHED" },
                { ExportSideToken("BACK", "Composite Accepted BF", "COMPOSITE_ACCEPTED_BF.png"),
                    "BACKSIDE_COMPOSITE_ACCEPTED_BF" },
                { ExportSideToken("BACK", "Composite Accepted DF", "COMPOSITE_ACCEPTED_DF_ENHANCED_DISPLAY_ONLY.png"),
                    "BACKSIDE_COMPOSITE_ACCEPTED_DF_ENHANCED_DISPLAY_ONLY" },
                { ExportSideToken("BACK", "Composite Accepted DF", "COMPOSITE_ACCEPTED_DF_UNTOUCHED.png"),
                    "BACKSIDE_COMPOSITE_ACCEPTED_DF_UNTOUCHED" },
                { ExportSideToken("BACK", "Frontside BF", "FRONTSIDE_BF_LOT_DASHBOARD.png"),
                    "FRONTSIDE_BF" }
            };
            foreach (KeyValuePair<string, string> item in cases)
                if (!String.Equals(item.Key, item.Value, StringComparison.Ordinal))
                    throw new InvalidDataException("Export-side filename contract failed: " +
                        item.Key + " != " + item.Value);
        }

        private string SelectedSide()
        {
            if (tabs.SelectedTab == null)
                return ExportSideToken(result.InspectionSide, "BF", String.Empty);
            return ExportSideToken(result.InspectionSide, tabs.SelectedTab.Text,
                SelectedImagePath());
        }
    }

    internal static class VerifiedFileCopy
    {
        public static void Copy(string source, string target, bool overwrite)
        {
            if (!File.Exists(source))
                throw new FileNotFoundException("Source image was not found.", source);
            string parent = Path.GetDirectoryName(Path.GetFullPath(target));
            if (String.IsNullOrWhiteSpace(parent) || !Directory.Exists(parent))
                throw new DirectoryNotFoundException("Export folder was not found: " + parent);
            if (!overwrite && File.Exists(target))
                throw new IOException("Refusing to overwrite export: " + target);

            File.Copy(source, target, overwrite);
            if (!String.Equals(Sha256(source), Sha256(target), StringComparison.Ordinal))
                throw new IOException("Export verification failed: copied PNG hash does not match source.");
        }

        public static string Sha256(string path)
        {
            using (SHA256 hash = SHA256.Create())
            using (FileStream stream = File.OpenRead(path))
                return BitConverter.ToString(hash.ComputeHash(stream)).Replace("-", "");
        }
    }

    internal sealed class ShareQueueReceipt
    {
        public string ReadyPackage;
        public string Payload;
        public string Sha256;
        public long Bytes;
        public int Width;
        public int Height;
    }

    internal static class ShareImageQueue
    {
        public static ShareQueueReceipt Enqueue(string source, string queueRoot,
            string lot, DateTime scanTime, int waferCount, string side, string relayState)
        {
            if (String.IsNullOrWhiteSpace(queueRoot))
                throw new InvalidOperationException("Image-sharing queue root is not configured.");
            string root = Path.GetFullPath(queueRoot);
            string pending = Path.Combine(root, "pending");
            Directory.CreateDirectory(pending);

            string sideToken = side.StartsWith("FRONT", StringComparison.OrdinalIgnoreCase) ? "F" : "B";
            string packageId = "IMG__" + SafeToken(lot) + "__" +
                scanTime.ToString("yyyyMMddTHHmmss") + "__" + sideToken + "__" +
                DateTime.UtcNow.ToString("yyyyMMddTHHmmssfffZ");
            string partialPackage = Path.Combine(pending, packageId + ".partial");
            string readyPackage = Path.Combine(pending, packageId + ".ready");
            if (Directory.Exists(partialPackage) || Directory.Exists(readyPackage) ||
                File.Exists(partialPackage) || File.Exists(readyPackage))
                throw new IOException("Refusing to overwrite image-sharing package: " + packageId);
            Directory.CreateDirectory(partialPackage);

            string payloadName = SafeToken(lot) + "_" + scanTime.ToString("yyyyMMddTHHmmss") +
                "_" + sideToken + ".png";
            string payload = Path.Combine(partialPackage, payloadName);
            VerifiedFileCopy.Copy(source, payload, false);
            string sha256 = VerifiedFileCopy.Sha256(payload);
            long bytes = new FileInfo(payload).Length;
            int width;
            int height;
            using (Image image = Image.FromFile(payload))
            {
                width = image.Width;
                height = image.Height;
            }

            Dictionary<string, object> manifest = new Dictionary<string, object>();
            manifest["schema"] = "argos_share_image_queue_manifest_v1";
            manifest["createdUtc"] = DateTime.UtcNow.ToString("o");
            manifest["state"] = "READY_LOCAL_AWAITING_RELAY";
            manifest["relayState"] = relayState;
            manifest["productionDataRoute"] = false;
            manifest["reviewOnly"] = true;
            manifest["packageId"] = packageId;
            manifest["lot"] = lot;
            manifest["scanTimestampLocal"] = scanTime.ToString("yyyy-MM-ddTHH:mm:ss");
            manifest["side"] = side;
            manifest["waferCount"] = waferCount;
            manifest["payloadFile"] = payloadName;
            manifest["width"] = width;
            manifest["height"] = height;
            manifest["bytes"] = bytes;
            manifest["sha256"] = sha256;
            manifest["sourceImage"] = Path.GetFullPath(source);
            string manifestPath = Path.Combine(partialPackage, "SHARE_IMAGE_MANIFEST.json");
            string json = new JavaScriptSerializer().Serialize(manifest) + Environment.NewLine;
            File.WriteAllText(manifestPath, json, new UTF8Encoding(false));

            Directory.Move(partialPackage, readyPackage);
            return new ShareQueueReceipt {
                ReadyPackage = readyPackage,
                Payload = Path.Combine(readyPackage, payloadName),
                Sha256 = sha256,
                Bytes = bytes,
                Width = width,
                Height = height
            };
        }

        private static string SafeToken(string value)
        {
            char[] invalid = Path.GetInvalidFileNameChars();
            return new string((value ?? "UNKNOWN").Select(ch =>
                invalid.Contains(ch) || Char.IsWhiteSpace(ch) ? '_' : ch).ToArray());
        }
    }

    internal sealed class MainWindow : Form
    {
        private DashboardManifest manifest;
        private readonly string manifestPath;
        private readonly Label status;
        private readonly Label filteredCount;
        private readonly Label manifestRevision;
        private readonly CheckBox showAllDates;
        private readonly DateTimePicker scanDate;
        private readonly DataGridView scanList;
        private readonly DataGridView holdList;
        private readonly Button generate;
        private readonly TrackBar overlayVisibility;
        private readonly Label overlayVisibilityValue;

        internal string[] SelectorColumnTitles
        {
            get { return scanList.Columns.Cast<DataGridViewColumn>().Select(item => item.HeaderText).ToArray(); }
        }

        internal string[] SelectorVisitSides
        {
            get
            {
                return scanList.Rows.Cast<DataGridViewRow>().Where(item => !item.IsNewRow)
                    .Select(item => String.Join("/", ((DataGridViewComboBoxCell)item.Cells[0]).Items
                        .Cast<object>().Select(value => Convert.ToString(value, CultureInfo.InvariantCulture)).ToArray()))
                    .ToArray();
            }
        }

        internal int SelectorVisitCount
        {
            get { return scanList.Rows.Cast<DataGridViewRow>().Count(item => !item.IsNewRow); }
        }

        internal int HeldAcquisitionCount { get { return holdList.Rows.Count; } }

        internal bool SelectorDefaultsToAllDates
        {
            get { return showAllDates.Checked && !scanDate.Enabled; }
        }

        internal bool SelectorUsesCellSelection
        {
            get { return scanList.SelectionMode == DataGridViewSelectionMode.CellSelect; }
        }

        public MainWindow(DashboardManifest dashboardManifest, string loadedManifestPath)
        {
            CatalogContract.Validate(dashboardManifest);
            manifest = dashboardManifest;
            manifestPath = Path.GetFullPath(loadedManifestPath);
            Text = "ArgosEdgeLab Review - JBOD Inspection Review Clone";
            Width = 1120;
            Height = 820;
            BackColor = Color.FromArgb(14, 19, 23);
            ForeColor = Color.White;
            Font = new Font("Segoe UI", 11);

            TabControl tabs = new TabControl { Dock = DockStyle.Fill };
            TabPage reportTab = new TabPage("Inspection Review and Lot Reports");
            reportTab.BackColor = BackColor;
            reportTab.ForeColor = ForeColor;

            Label heading = new Label {
                Text = "Composite accepted inspection review", Font = new Font("Segoe UI", 22, FontStyle.Bold),
                Left = 28, Top = 22, Width = 760, Height = 46
            };
            Label note = new Label {
                Text = "All eligible completed visits are shown by default, newest first. Clear Show all dates to apply the visible date filter. Each row remains one exact lot/timestamp visit with independent FRONT/BACK selection.",
                Left = 30, Top = 72, Width = 1000, Height = 46
            };
            Label dateLabel = new Label { Text = "Optional date filter", Left = 30, Top = 126, Width = 180, Height = 28 };
            scanDate = new DateTimePicker {
                Left = 30, Top = 154, Width = 190, Height = 34,
                Format = DateTimePickerFormat.Custom, CustomFormat = "yyyy-MM-dd"
            };
            scanDate.ValueChanged += delegate { if (!showAllDates.Checked) PopulateScanList(); };
            showAllDates = new CheckBox {
                Text = "Show all dates", Left = 245, Top = 157, Width = 190, Height = 30,
                Checked = true, ForeColor = Color.White
            };
            showAllDates.CheckedChanged += delegate {
                scanDate.Enabled = !showAllDates.Checked;
                PopulateScanList();
            };
            filteredCount = new Label { Left = 450, Top = 159, Width = 610, Height = 30 };
            manifestRevision = new Label {
                Left = 30, Top = 188, Width = 850, Height = 20,
                Font = new Font("Segoe UI", 8), AutoEllipsis = true
            };
            Button reloadManifest = new Button {
                Text = "Reload manifest", Left = 890, Top = 178, Width = 170, Height = 28,
                BackColor = Color.FromArgb(72, 92, 112), ForeColor = Color.White
            };
            reloadManifest.Click += ReloadManifest;

            scanList = new DataGridView {
                Left = 30, Top = 210, Width = 1030, Height = 280,
                MultiSelect = false, SelectionMode = DataGridViewSelectionMode.CellSelect,
                AllowUserToAddRows = false, AllowUserToDeleteRows = false,
                AllowUserToResizeRows = false, RowHeadersVisible = false,
                AutoGenerateColumns = false, EditMode = DataGridViewEditMode.EditOnEnter,
                BackgroundColor = Color.FromArgb(20, 27, 32), BorderStyle = BorderStyle.FixedSingle,
                GridColor = Color.FromArgb(89, 108, 118), ForeColor = Color.White,
                ColumnHeadersDefaultCellStyle = new DataGridViewCellStyle {
                    BackColor = Color.FromArgb(238, 238, 238), ForeColor = Color.Black,
                    SelectionBackColor = Color.FromArgb(238, 238, 238), SelectionForeColor = Color.Black
                },
                DefaultCellStyle = new DataGridViewCellStyle {
                    BackColor = Color.FromArgb(20, 27, 32), ForeColor = Color.White,
                    SelectionBackColor = Color.FromArgb(31, 103, 127), SelectionForeColor = Color.White
                }
            };
            scanList.EnableHeadersVisualStyles = false;
            scanList.Columns.Add(new DataGridViewComboBoxColumn {
                Name = "Side", HeaderText = "Side", Width = 105,
                FlatStyle = FlatStyle.Flat, DisplayStyle = DataGridViewComboBoxDisplayStyle.DropDownButton
            });
            scanList.Columns.Add(TextColumn("Lot", 150));
            scanList.Columns.Add(TextColumn("Scan date/time", 165));
            scanList.Columns.Add(TextColumn("Wafers", 75));
            scanList.Columns.Add(TextColumn("Product", 160));
            scanList.Columns.Add(TextColumn("Process block", 170));
            scanList.Columns.Add(TextColumn("Step", 210));
            scanList.Columns.Add(TextColumn("Last tool", 150));
            scanList.CurrentCellChanged += ScanSelectionChanged;
            scanList.CurrentCellDirtyStateChanged += delegate {
                if (scanList.IsCurrentCellDirty) scanList.CommitEdit(DataGridViewDataErrorContexts.Commit);
            };
            scanList.CellValueChanged += ScanSelectionChanged;
            scanList.CellDoubleClick += delegate(object sender, DataGridViewCellEventArgs e) {
                if (e.RowIndex >= 0 && e.ColumnIndex == 0 && generate.Enabled)
                    GenerateClicked(generate, EventArgs.Empty);
            };

            generate = new Button {
                Text = "Open selected side BF / DF", Left = 30, Top = 510,
                Width = 370, Height = 54, BackColor = Color.FromArgb(31, 103, 127),
                ForeColor = Color.White, Enabled = false
            };
            generate.Click += GenerateClicked;

            Label overlayLabel = new Label {
                Text = "Composite visibility (fixed)", Left = 430, Top = 505,
                Width = 260, Height = 28
            };
            overlayVisibility = new TrackBar {
                Left = 680, Top = 498, Width = 285, Height = 55,
                Minimum = 5, Maximum = 100, TickFrequency = 5,
                SmallChange = 5, LargeChange = 10,
                Value = 100, Enabled = false
            };
            overlayVisibilityValue = new Label {
                Left = 972, Top = 507, Width = 78, Height = 28
            };
            overlayVisibility.Scroll += delegate { UpdateOverlayVisibilityLabel(); };
            UpdateOverlayVisibilityLabel();
            status = new Label { Left = 30, Top = 580, Width = 1020, Height = 62,
                Text = "Select FRONT or BACK in the Side column for one cataloged lot scan." };

            GroupBox xmlHold = new GroupBox {
                Text = "XML export", Left = 30, Top = 650, Width = 1030, Height = 72,
                ForeColor = Color.FromArgb(255, 205, 92)
            };
            xmlHold.Controls.Add(new Label {
                Left = 16, Top = 28, Width = 990, Height = 30,
                Text = "Disabled - awaiting approved Data Engineering bins and coordinate authority. No XML is generated from this tab."
            });

            reportTab.Controls.Add(heading);
            reportTab.Controls.Add(note);
            reportTab.Controls.Add(dateLabel);
            reportTab.Controls.Add(scanDate);
            reportTab.Controls.Add(showAllDates);
            reportTab.Controls.Add(filteredCount);
            reportTab.Controls.Add(manifestRevision);
            reportTab.Controls.Add(reloadManifest);
            reportTab.Controls.Add(scanList);
            reportTab.Controls.Add(generate);
            reportTab.Controls.Add(overlayLabel);
            reportTab.Controls.Add(overlayVisibility);
            reportTab.Controls.Add(overlayVisibilityValue);
            reportTab.Controls.Add(status);
            reportTab.Controls.Add(xmlHold);
            tabs.TabPages.Add(reportTab);

            TabPage holdTab = new TabPage("Inspection Holds") { BackColor = BackColor, ForeColor = ForeColor };
            holdTab.Controls.Add(new Label { Dock = DockStyle.Top, Height = 58, Padding = new Padding(12),
                Text = "Current acquisitions without a completed current-fingerprint result. Reasons are preserved exactly; these rows cannot open or generate inspection imagery." });
            holdList = new DataGridView { Dock = DockStyle.Fill, ReadOnly = true, MultiSelect = false,
                SelectionMode = DataGridViewSelectionMode.FullRowSelect, AllowUserToAddRows = false,
                AllowUserToDeleteRows = false, RowHeadersVisible = false, AutoGenerateColumns = false,
                BackgroundColor = Color.FromArgb(20, 27, 32), ForeColor = Color.White,
                DefaultCellStyle = new DataGridViewCellStyle { BackColor = Color.FromArgb(20, 27, 32), ForeColor = Color.White },
                ColumnHeadersDefaultCellStyle = new DataGridViewCellStyle { BackColor = Color.FromArgb(238, 238, 238), ForeColor = Color.Black } };
            holdList.EnableHeadersVisualStyles = false;
            holdList.Columns.Add(TextColumn("Scan date/time", 150)); holdList.Columns.Add(TextColumn("Lot", 130));
            holdList.Columns.Add(TextColumn("Slot", 60)); holdList.Columns.Add(TextColumn("Wafer ID", 125));
            holdList.Columns.Add(TextColumn("Affected domains", 210)); holdList.Columns.Add(TextColumn("Actionability", 210));
            holdList.Columns.Add(TextColumn("Exact state / reason", 330)); holdList.Columns.Add(TextColumn("Next action", 280));
            holdList.Columns.Add(TextColumn("Proposal source", 250)); holdList.Columns.Add(TextColumn("Detail", 350));
            holdTab.Controls.Add(holdList); holdList.BringToFront(); tabs.TabPages.Add(holdTab);
            Controls.Add(tabs);

            InitializeDateFilter();
        }

        private static DataGridViewTextBoxColumn TextColumn(string title, int width)
        {
            return new DataGridViewTextBoxColumn {
                HeaderText = title, Width = width, ReadOnly = true,
                SortMode = DataGridViewColumnSortMode.NotSortable
            };
        }

        private void ReloadManifest(object sender, EventArgs e)
        {
            try
            {
                manifest = Program.LoadManifest(manifestPath);
                InitializeDateFilter();
                status.Text = "Reloaded and revalidated the exact dashboard manifest. No processor or inspection task was restarted.";
            }
            catch (Exception ex)
            {
                status.Text = "Manifest reload failed; the last validated in-memory manifest remains displayed: " + ex.Message;
                MessageBox.Show(this, ex.Message, "Manifest reload failed",
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void UpdateManifestRevision()
        {
            string readiness = "dashboard status unavailable";
            string statusPath = Path.Combine(Path.GetDirectoryName(manifestPath),
                "dashboard", "DASHBOARD_CATALOG_STATUS.json");
            if (File.Exists(statusPath))
            {
                DashboardCatalogStatus dashboardStatus = new JavaScriptSerializer()
                    .Deserialize<DashboardCatalogStatus>(File.ReadAllText(statusPath));
                readiness = dashboardStatus.state + " updated " + dashboardStatus.updatedUtc +
                    "; included wafers " + dashboardStatus.includedWafers.ToString(CultureInfo.InvariantCulture);
            }
            manifestRevision.Text = "Manifest " + manifest.createdUtc + " | SHA-256 " +
                Program.FileSha256(manifestPath) + " | " + readiness + " | " + manifestPath;
        }

        private void InitializeDateFilter()
        {
            DateTime minimum = manifest.scanSessions.Count == 0 ? DateTime.Today : manifest.scanSessions.Min(item => item.ScanTime).Date;
            DateTime maximum = manifest.scanSessions.Count == 0 ? DateTime.Today : manifest.scanSessions.Max(item => item.ScanTime).Date;
            scanDate.MinDate = minimum;
            scanDate.MaxDate = maximum;
            scanDate.Value = maximum;
            scanDate.Enabled = !showAllDates.Checked;
            UpdateManifestRevision();
            PopulateScanList();
            PopulateHoldList();
        }

        private void PopulateHoldList()
        {
            holdList.Rows.Clear();
            foreach (HeldDisplayRow held in Program.ProjectHeldRows(manifest.heldAcquisitions))
                holdList.Rows.Add(held.scanTimestampLocal, held.lot, held.slot, held.waferId, held.domains,
                    held.actionability, held.exactStateOrReason, held.nextAction, held.proposalSource, held.detail);
        }

        private void PopulateScanList()
        {
            scanList.SuspendLayout();
            try
            {
                scanList.Rows.Clear();
                generate.Enabled = false;
                List<ScanVisit> matches = showAllDates.Checked
                    ? ScanSessionQuery.VisitsForAllDates(manifest.scanSessions)
                    : ScanSessionQuery.VisitsForDate(manifest.scanSessions, scanDate.Value.Date);
                foreach (ScanVisit visit in matches)
                {
                    List<WaferRecord> wafers = visit.Wafers.ToList();
                    string product = DistinctSummary(wafers.Select(item => item.product));
                    string process = DistinctSummary(wafers.Select(item => item.processBlock));
                    string step = DistinctSummary(wafers.Select(item => item.step));
                    string lastTool = DistinctSummary(wafers.Select(item => item.lastTool));
                    int frontCount = visit.front == null ? -1 : visit.front.wafers.Count;
                    int backCount = visit.back == null ? -1 : visit.back.wafers.Count;
                    string waferCount = frontCount >= 0 && backCount >= 0 && frontCount != backCount
                        ? frontCount.ToString(CultureInfo.InvariantCulture) + "F / " +
                            backCount.ToString(CultureInfo.InvariantCulture) + "B"
                        : Math.Max(frontCount, backCount).ToString(CultureInfo.InvariantCulture);
                    int rowIndex = scanList.Rows.Add();
                    DataGridViewRow row = scanList.Rows[rowIndex];
                    DataGridViewComboBoxCell sideCell = (DataGridViewComboBoxCell)row.Cells[0];
                    if (visit.front != null) sideCell.Items.Add("FRONT");
                    if (visit.back != null) sideCell.Items.Add("BACK");
                    sideCell.Value = visit.front != null ? "FRONT" : "BACK";
                    row.Cells[1].Value = visit.lot;
                    row.Cells[2].Value = visit.scanTime.ToString("yyyy-MM-dd HH:mm:ss");
                    row.Cells[3].Value = waferCount;
                    row.Cells[4].Value = product;
                    row.Cells[5].Value = process;
                    row.Cells[6].Value = step;
                    row.Cells[7].Value = lastTool;
                    row.Tag = visit;
                }
                scanList.ClearSelection();
                scanList.CurrentCell = null;
                string scope = showAllDates.Checked ? "across all dates" : "on " + scanDate.Value.ToString("yyyy-MM-dd");
                filteredCount.Text = scanList.Rows.Count == 1
                    ? "1 exact scan visit " + scope + ". Choose its FRONT or BACK side."
                    : scanList.Rows.Count + " exact scan visits " + scope + ". Newest visits are first.";
                status.Text = scanList.Rows.Count == 0
                    ? "No eligible scan sessions are cataloged " + scope + "."
                    : "Choose FRONT or BACK in the Side cell for the scan visit to open. No XML will be generated.";
            }
            finally { scanList.ResumeLayout(); }
        }

        private static string DistinctSummary(IEnumerable<string> values)
        {
            List<string> distinct = values.Where(value => !String.IsNullOrWhiteSpace(value))
                .Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(value => value).ToList();
            if (distinct.Count == 0) return "-";
            if (distinct.Count <= 2) return String.Join(" / ", distinct.ToArray());
            return distinct[0] + " + " + (distinct.Count - 1) + " more";
        }

        private void ScanSelectionChanged(object sender, EventArgs e)
        {
            ScanVisit visit;
            ScanSession selected;
            generate.Enabled = TryGetSelectedSession(out visit, out selected);
            if (!generate.Enabled) return;
            status.Text = "Selected " + ScanSessionQuery.InspectionSide(selected) + " for lot " + visit.lot + " scanned " +
                visit.scanTime.ToString("yyyy-MM-dd HH:mm:ss") + " with " +
                selected.wafers.Count + " wafers.";
        }

        private bool TryGetSelectedSession(out ScanVisit visit, out ScanSession session)
        {
            visit = null;
            session = null;
            if (scanList.CurrentCell == null || scanList.CurrentCell.ColumnIndex != 0 ||
                scanList.CurrentCell.RowIndex < 0) return false;
            DataGridViewRow row = scanList.Rows[scanList.CurrentCell.RowIndex];
            visit = row.Tag as ScanVisit;
            string side = Convert.ToString(row.Cells[0].Value, CultureInfo.InvariantCulture);
            session = visit == null ? null : visit.SessionForSide(side);
            return session != null;
        }

        private void UpdateOverlayVisibilityLabel()
        {
            overlayVisibilityValue.Text = overlayVisibility.Value + "%";
        }

        private void GenerateClicked(object sender, EventArgs e)
        {
            ScanVisit visit;
            ScanSession selected;
            if (!TryGetSelectedSession(out visit, out selected)) return;
            try
            {
                status.Text = "Opening " + ScanSessionQuery.InspectionSide(selected) +
                    " composite accepted BF/DF for lot " + selected.lot + "...";
                Application.DoEvents();
                DashboardResult result = DashboardGenerator.Generate(manifest, selected,
                    overlayVisibility.Value / 100.0);
                status.Text = "Created " + result.WaferCount + "-wafer dashboard: " + result.DirectoryPath;
                DashboardWindow popup = new DashboardWindow(result);
                popup.Show(this);
            }
            catch (Exception ex)
            {
                status.Text = "Generation failed: " + ex.Message;
                MessageBox.Show(this, ex.ToString(), "Dashboard generation failed",
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }

    internal static class Program
    {
        internal const string ScribeHoldReason = "HOLD_SCRIBE_CONFIRMATION_REQUIRED_BEFORE_DETECTOR";

        internal static List<HeldDisplayRow> ProjectHeldRows(IEnumerable<HeldAcquisition> rows)
        {
            List<HeldDisplayRow> projected = rows
                .Where(item => !String.Equals(item.holdReason, ScribeHoldReason, StringComparison.Ordinal))
                .Select(item => NewHeldDisplayRow(item, item.domain)).ToList();
            foreach (IGrouping<string, HeldAcquisition> group in rows
                .Where(item => String.Equals(item.holdReason, ScribeHoldReason, StringComparison.Ordinal))
                .GroupBy(item => String.IsNullOrWhiteSpace(item.physicalIdentity) ? item.identity : item.physicalIdentity,
                    StringComparer.OrdinalIgnoreCase))
            {
                HeldAcquisition first = group.OrderByDescending(item => item.scanTimestampLocal).First();
                string domains = String.Join(" + ", group.Select(item => item.domain == "FRONTSIDE" ? "FRONT" : item.domain)
                    .Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(item => item == "FRONT" ? 0 : 1).ThenBy(item => item));
                projected.Add(NewHeldDisplayRow(first, domains));
            }
            return projected.OrderByDescending(item => item.scanTimestampLocal).ToList();
        }

        private static HeldDisplayRow NewHeldDisplayRow(HeldAcquisition item, string domains)
        {
            bool scribe = String.Equals(item.holdReason, ScribeHoldReason, StringComparison.Ordinal);
            return new HeldDisplayRow {
                scanTimestampLocal=item.scanTimestampLocal, lot=item.lot, slot=item.slot, waferId=item.waferId,
                domains=domains, actionability=scribe ? item.scribeActionability : String.Empty,
                exactStateOrReason=scribe ? item.scribeQueueState : item.holdReason,
                nextAction=scribe ? item.scribeNextAction : String.Empty,
                proposalSource=scribe ? item.scribeProposalSource : String.Empty, detail=item.holdDetail
            };
        }

        internal static string FileSha256(string path)
        {
            using (SHA256 sha = SHA256.Create())
            using (FileStream stream = File.OpenRead(path))
                return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", String.Empty);
        }

        internal static DashboardManifest LoadManifest(string manifestPath)
        {
            JavaScriptSerializer serializer = new JavaScriptSerializer { MaxJsonLength = 64 * 1024 * 1024 };
            DashboardManifest loaded = serializer.Deserialize<DashboardManifest>(File.ReadAllText(manifestPath));
            string appDir = Path.GetDirectoryName(Path.GetFullPath(manifestPath));
            if (loaded.shareImageQueueEnabled && !Path.IsPathRooted(loaded.shareImageQueueRoot))
                loaded.shareImageQueueRoot = Path.GetFullPath(Path.Combine(appDir, loaded.shareImageQueueRoot));
            CatalogContract.Validate(loaded);
            return loaded;
        }

        [STAThread]
        private static int Main(string[] args)
        {
            try
            {
                string appDir = AppDomain.CurrentDomain.BaseDirectory;
                string manifestPath = Path.Combine(appDir, "dashboard_manifest.json");
                if (args.Length == 4 && String.Equals(args[0], "--hold-projection-check",
                    StringComparison.OrdinalIgnoreCase))
                {
                    DashboardManifest fixture = new JavaScriptSerializer { MaxJsonLength = 64 * 1024 * 1024 }
                        .Deserialize<DashboardManifest>(File.ReadAllText(manifestPath));
                    List<HeldDisplayRow> display = ProjectHeldRows(fixture.heldAcquisitions);
                    int expectedRows = Int32.Parse(args[1], CultureInfo.InvariantCulture);
                    int expectedScribeRows = Int32.Parse(args[2], CultureInfo.InvariantCulture);
                    int expectedReady = Int32.Parse(args[3], CultureInfo.InvariantCulture);
                    if (display.Count != expectedRows ||
                        display.Count(item => !String.IsNullOrWhiteSpace(item.actionability)) != expectedScribeRows ||
                        display.Count(item => item.actionability == "OPERATOR_REVIEW_READY") != expectedReady ||
                        display.Count(item => !String.IsNullOrWhiteSpace(item.actionability) &&
                            item.domains != "FRONT + BACKSIDE_PENDING_REGIME") != 0)
                        throw new InvalidDataException("Held-row physical grouping or actionability contract failed.");
                    return 0;
                }
                DashboardManifest manifest = LoadManifest(manifestPath);
                ScanSessionQuery.AssertRepeatedLotVisitsRemainDistinct();
                ScanSessionQuery.AssertInspectionSideLabels();
                DashboardWindow.AssertExportSideNameContract();

                if (args.Length > 0 && String.Equals(args[0], "--catalog-check",
                    StringComparison.OrdinalIgnoreCase))
                    return 0;
                if (args.Length > 0 && String.Equals(args[0], "--export-name-smoke",
                    StringComparison.OrdinalIgnoreCase))
                    return 0;
                if (args.Length > 0 && String.Equals(args[0], "--ui-smoke",
                    StringComparison.OrdinalIgnoreCase))
                {
                    Application.EnableVisualStyles();
                    Application.SetCompatibleTextRenderingDefault(false);
                    using (MainWindow window = new MainWindow(manifest, manifestPath))
                    {
                        window.CreateControl();
                        if (window.HeldAcquisitionCount != Program.ProjectHeldRows(manifest.heldAcquisitions).Count)
                            throw new InvalidDataException("Rendered hold rows do not match the catalog.");
                    }
                    return 0;
                }
                if (args.Length > 0 && String.Equals(args[0], "--side-selector-smoke",
                    StringComparison.OrdinalIgnoreCase))
                {
                    Application.EnableVisualStyles();
                    Application.SetCompatibleTextRenderingDefault(false);
                    using (MainWindow window = new MainWindow(manifest, manifestPath))
                    {
                        window.CreateControl();
                        if (window.SelectorColumnTitles.Length == 0 ||
                            !String.Equals(window.SelectorColumnTitles[0], "Side", StringComparison.Ordinal) ||
                            !window.SelectorUsesCellSelection)
                            throw new InvalidDataException("Side-first cell-selection UI contract failed.");
                        List<ScanVisit> expectedVisits = ScanSessionQuery.VisitsForAllDates(manifest.scanSessions);
                        string[] expectedSides = expectedVisits.Select(item =>
                            item.front != null && item.back != null ? "FRONT/BACK" :
                            (item.front != null ? "FRONT" : "BACK")).ToArray();
                        if (!window.SelectorDefaultsToAllDates ||
                            window.SelectorVisitCount != expectedVisits.Count ||
                            !window.SelectorVisitSides.SequenceEqual(expectedSides))
                            throw new InvalidDataException("Rendered scan-visit rows or FRONT/BACK choices do not match the catalog.");
                    }
                    return 0;
                }
                if (args.Length > 0 && String.Equals(args[0], "--inspection-window-smoke",
                    StringComparison.OrdinalIgnoreCase))
                {
                    ScanSession selected = manifest.scanSessions.OrderByDescending(item => item.ScanTime).First();
                    DashboardResult result = DashboardGenerator.Generate(manifest, selected,
                        manifest.defectOverlayOpacity);
                    Application.EnableVisualStyles();
                    Application.SetCompatibleTextRenderingDefault(false);
                    using (DashboardWindow window = new DashboardWindow(result))
                    {
                        window.CreateControl();
                        string[] expected = new[] { "Composite Accepted BF", "Composite Accepted DF" };
                        if (!result.HasFullInspectionReview || window.ReviewTabCount != expected.Length ||
                            !window.ReviewTabTitles.SequenceEqual(expected))
                            throw new InvalidDataException("Two-view composite accepted inspection-window contract failed.");
                    }
                    return 0;
                }
                if (args.Length > 0 && String.Equals(args[0], "--generate-only",
                    StringComparison.OrdinalIgnoreCase))
                {
                    ScanSession selected = null;
                    if (args.Length > 1)
                        selected = manifest.scanSessions.FirstOrDefault(item => String.Equals(
                            item.scanId, args[1], StringComparison.OrdinalIgnoreCase));
                    else
                        selected = manifest.scanSessions.OrderByDescending(item => item.ScanTime).First();
                    if (selected == null)
                        throw new InvalidDataException("Requested scanId is not cataloged: " + args[1]);
                    DashboardGenerator.Generate(manifest, selected,
                        manifest.defectOverlayOpacity);
                    return 0;
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new MainWindow(manifest, manifestPath));
                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex.ToString());
                return 1;
            }
        }
    }
}
