using ProTechTiveGear.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using Dapper;
using System.Data.Entity;

namespace ProTechTiveGear.Controllers
{
    public class ProductStat
    {
        public string TypeName { get; set; }
        public int SLBan { get; set; }
    }

    public class SummaryController : Controller
    {
        ProTechTiveGearEntities db = new ProTechTiveGearEntities();

        // GET: Summary
        public ActionResult Index()
        {
            return View();
        }

        public JsonResult GetProductStats()
        {
            string sqlQuery = @"
                SELECT ItemType.TypeName, SUM(ISNULL(OrderDetail.Quantity, 0)) AS SLBan FROM ItemType
                    LEFT JOIN Item ON Item.TypeID = ItemType.ID
                    LEFT JOIN OrderDetail ON OrderDetail.ItemId = Item.ID
                    GROUP BY ItemType.TypeName
                    ORDER BY SUM(ISNULL(OrderDetail.Quantity, 0)) desc
";

            var starts = db.Database.SqlQuery<ProductStat>(sqlQuery)
                .ToList();

            return Json(starts, JsonRequestBehavior.AllowGet);
        }
    }
}