var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);
var transport_controller_exports = {};
__export(transport_controller_exports, {
  TransportController: () => TransportController,
  default: () => transport_controller_default
});
module.exports = __toCommonJS(transport_controller_exports);
var import_sequelize = require("sequelize");
class TransportController {
  // =========================================================================
  // VEHICLE MANAGEMENT
  // =========================================================================
  static async listVehicles(req, res) {
    try {
      const outlet_id = req.user.outlet_id;
      const { status, search } = req.query;
      const where = { outlet_id, is_active: true };
      if (status && status !== "ALL") {
        where.status = status;
      }
      if (search) {
        where[import_sequelize.Op.or] = [
          { vehicle_number: { [import_sequelize.Op.iLike]: `%${search}%` } },
          { vehicle_type: { [import_sequelize.Op.iLike]: `%${search}%` } },
          { model: { [import_sequelize.Op.iLike]: `%${search}%` } }
        ];
      }
      const vehicles = await req.propertyDb.models.transport_vehicles.findAll({
        where,
        include: [
          {
            model: req.propertyDb.models.transport_drivers,
            as: "current_driver",
            required: false,
            attributes: ["id", "driver_name", "phone", "license_number"]
          }
        ],
        order: [["vehicle_number", "ASC"]]
      });
      return res.json({ success: true, data: vehicles });
    } catch (err) {
      console.error("listVehicles error:", err);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
  static async createVehicle(req, res) {
    try {
      const outlet_id = req.user.outlet_id;
      const {
        vehicle_number,
        vehicle_type,
        capacity_tonnage,
        capacity_unit,
        model,
        notes
      } = req.body;
      if (!vehicle_number || !vehicle_number.trim()) {
        return res.status(400).json({ success: false, message: "Vehicle number is required" });
      }
      const formattedNumber = vehicle_number.trim().toUpperCase();
      const existing = await req.propertyDb.models.transport_vehicles.findOne({
        where: { outlet_id, vehicle_number: formattedNumber, is_active: true }
      });
      if (existing) {
        return res.status(400).json({ success: false, message: `Vehicle ${formattedNumber} already exists.` });
      }
      const vehicle = await req.propertyDb.models.transport_vehicles.create({
        outlet_id,
        vehicle_number: formattedNumber,
        vehicle_type: vehicle_type || "Truck",
        capacity_tonnage: parseFloat(capacity_tonnage) || 0,
        capacity_unit: capacity_unit || "Tons",
        model: model ? model.trim() : null,
        status: "AVAILABLE",
        notes: notes ? notes.trim() : null,
        is_active: true
      });
      return res.status(201).json({ success: true, data: vehicle, message: "Vehicle added successfully" });
    } catch (err) {
      console.error("createVehicle error:", err);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
  static async updateVehicle(req, res) {
    try {
      const outlet_id = req.user.outlet_id;
      const { id } = req.params;
      const {
        vehicle_number,
        vehicle_type,
        capacity_tonnage,
        capacity_unit,
        model,
        status,
        notes
      } = req.body;
      const vehicle = await req.propertyDb.models.transport_vehicles.findOne({
        where: { id, outlet_id }
      });
      if (!vehicle) {
        return res.status(404).json({ success: false, message: "Vehicle not found" });
      }
      await vehicle.update({
        vehicle_number: vehicle_number ? vehicle_number.trim().toUpperCase() : vehicle.vehicle_number,
        vehicle_type: vehicle_type || vehicle.vehicle_type,
        capacity_tonnage: capacity_tonnage !== void 0 ? parseFloat(capacity_tonnage) : vehicle.capacity_tonnage,
        capacity_unit: capacity_unit || vehicle.capacity_unit,
        model: model !== void 0 ? model ? model.trim() : null : vehicle.model,
        status: status || vehicle.status,
        notes: notes !== void 0 ? notes ? notes.trim() : null : vehicle.notes
      });
      return res.json({ success: true, data: vehicle, message: "Vehicle updated successfully" });
    } catch (err) {
      console.error("updateVehicle error:", err);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
  static async deleteVehicle(req, res) {
    try {
      const outlet_id = req.user.outlet_id;
      const { id } = req.params;
      const vehicle = await req.propertyDb.models.transport_vehicles.findOne({
        where: { id, outlet_id }
      });
      if (!vehicle) {
        return res.status(404).json({ success: false, message: "Vehicle not found" });
      }
      if (vehicle.status === "BOOKED" || vehicle.status === "IN_TRANSIT") {
        return res.status(400).json({ success: false, message: "Cannot delete vehicle while booked or on trip." });
      }
      await vehicle.update({ is_active: false });
      return res.json({ success: true, message: "Vehicle removed successfully" });
    } catch (err) {
      console.error("deleteVehicle error:", err);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
  // =========================================================================
  // DRIVER MANAGEMENT
  // =========================================================================
  static async listDrivers(req, res) {
    try {
      const outlet_id = req.user.outlet_id;
      const { status, search } = req.query;
      const where = { outlet_id, is_active: true };
      if (status && status !== "ALL") {
        where.status = status;
      }
      if (search) {
        where[import_sequelize.Op.or] = [
          { driver_name: { [import_sequelize.Op.iLike]: `%${search}%` } },
          { phone: { [import_sequelize.Op.iLike]: `%${search}%` } },
          { license_number: { [import_sequelize.Op.iLike]: `%${search}%` } }
        ];
      }
      const drivers = await req.propertyDb.models.transport_drivers.findAll({
        where,
        include: [
          {
            model: req.propertyDb.models.transport_vehicles,
            as: "current_vehicle",
            required: false,
            attributes: ["id", "vehicle_number", "vehicle_type", "model"]
          }
        ],
        order: [["driver_name", "ASC"]]
      });
      return res.json({ success: true, data: drivers });
    } catch (err) {
      console.error("listDrivers error:", err);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
  static async createDriver(req, res) {
    try {
      const outlet_id = req.user.outlet_id;
      const { driver_name, phone, license_number, address } = req.body;
      if (!driver_name || !driver_name.trim()) {
        return res.status(400).json({ success: false, message: "Driver name is required" });
      }
      if (!phone || !phone.trim()) {
        return res.status(400).json({ success: false, message: "Driver phone number is required" });
      }
      const driver = await req.propertyDb.models.transport_drivers.create({
        outlet_id,
        driver_name: driver_name.trim(),
        phone: phone.trim(),
        license_number: license_number ? license_number.trim().toUpperCase() : null,
        address: address ? address.trim() : null,
        status: "AVAILABLE",
        is_active: true
      });
      return res.status(201).json({ success: true, data: driver, message: "Driver profile created successfully" });
    } catch (err) {
      console.error("createDriver error:", err);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
  static async updateDriver(req, res) {
    try {
      const outlet_id = req.user.outlet_id;
      const { id } = req.params;
      const { driver_name, phone, license_number, address, status } = req.body;
      const driver = await req.propertyDb.models.transport_drivers.findOne({
        where: { id, outlet_id }
      });
      if (!driver) {
        return res.status(404).json({ success: false, message: "Driver not found" });
      }
      await driver.update({
        driver_name: driver_name ? driver_name.trim() : driver.driver_name,
        phone: phone ? phone.trim() : driver.phone,
        license_number: license_number !== void 0 ? license_number ? license_number.trim().toUpperCase() : null : driver.license_number,
        address: address !== void 0 ? address ? address.trim() : null : driver.address,
        status: status || driver.status
      });
      return res.json({ success: true, data: driver, message: "Driver profile updated successfully" });
    } catch (err) {
      console.error("updateDriver error:", err);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
  static async deleteDriver(req, res) {
    try {
      const outlet_id = req.user.outlet_id;
      const { id } = req.params;
      const driver = await req.propertyDb.models.transport_drivers.findOne({
        where: { id, outlet_id }
      });
      if (!driver) {
        return res.status(404).json({ success: false, message: "Driver not found" });
      }
      if (driver.status === "BOOKED" || driver.status === "ON_TRIP") {
        return res.status(400).json({ success: false, message: "Cannot delete driver while booked on an active trip." });
      }
      await driver.update({ is_active: false });
      return res.json({ success: true, message: "Driver profile removed successfully" });
    } catch (err) {
      console.error("deleteDriver error:", err);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
  // =========================================================================
  // TRIP ASSIGNMENT & MULTI-CHALLAN GROUPING PER TRUCK
  // =========================================================================
  static async assignTrip(req, res) {
    const t = await req.propertyDb.transaction();
    try {
      const outlet_id = req.user.outlet_id;
      const { vehicle_id, driver_id, challan_ids, e_way_bill_no, destination_address } = req.body;
      if (!vehicle_id) {
        await t.rollback();
        return res.status(400).json({ success: false, message: "Please select a vehicle/truck." });
      }
      if (!driver_id) {
        await t.rollback();
        return res.status(400).json({ success: false, message: "Please select a driver." });
      }
      if (!challan_ids || !Array.isArray(challan_ids) || challan_ids.length === 0) {
        await t.rollback();
        return res.status(400).json({ success: false, message: "Please select at least one delivery challan." });
      }
      const vehicle = await req.propertyDb.models.transport_vehicles.findOne({
        where: { id: vehicle_id, outlet_id },
        transaction: t
      });
      if (!vehicle) {
        await t.rollback();
        return res.status(404).json({ success: false, message: "Selected vehicle not found." });
      }
      const driver = await req.propertyDb.models.transport_drivers.findOne({
        where: { id: driver_id, outlet_id },
        transaction: t
      });
      if (!driver) {
        await t.rollback();
        return res.status(404).json({ success: false, message: "Selected driver not found." });
      }
      const today = /* @__PURE__ */ new Date();
      const dateStr = `${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, "0")}${String(today.getDate()).padStart(2, "0")}`;
      const tripRandom = Math.random().toString(36).substring(2, 6).toUpperCase();
      const trip_id = `TRIP-${dateStr}-${tripRandom}`;
      const assignedChallans = [];
      for (const challanId of challan_ids) {
        const challan = await req.propertyDb.models.delivery_challan_headers.findOne({
          where: { id: challanId, outlet_id },
          transaction: t
        });
        if (!challan) continue;
        const delivery_otp = String(Math.floor(1e5 + Math.random() * 9e5));
        await challan.update(
          {
            vehicle_id: vehicle.id,
            vehicle_number: vehicle.vehicle_number,
            vehicle_type: vehicle.vehicle_type,
            driver_id: driver.id,
            driver_name: driver.driver_name,
            driver_phone: driver.phone,
            trip_id,
            delivery_status: "IN_TRANSIT",
            delivery_otp,
            e_way_bill_no: e_way_bill_no || challan.e_way_bill_no,
            destination_address: destination_address || challan.destination_address,
            status: "In-Transit"
          },
          { transaction: t }
        );
        assignedChallans.push({
          id: challan.id,
          challan_no: challan.challan_no,
          customer_name: challan.customer_name,
          delivery_otp
        });
      }
      await vehicle.update(
        {
          status: "BOOKED",
          current_trip_id: trip_id,
          current_driver_id: driver.id
        },
        { transaction: t }
      );
      await driver.update(
        {
          status: "BOOKED",
          current_vehicle_id: vehicle.id
        },
        { transaction: t }
      );
      await t.commit();
      return res.json({
        success: true,
        message: `Successfully booked Truck ${vehicle.vehicle_number} with Driver ${driver.driver_name} for ${assignedChallans.length} delivery challan(s).`,
        data: {
          trip_id,
          vehicle_number: vehicle.vehicle_number,
          driver_name: driver.driver_name,
          driver_phone: driver.phone,
          challans: assignedChallans
        }
      });
    } catch (err) {
      await t.rollback();
      console.error("assignTrip error:", err);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
  // =========================================================================
  // VERIFY DELIVERY (OTP OR DRIVER SUBMIT CONFIRMATION)
  // =========================================================================
  static async verifyDelivery(req, res) {
    const t = await req.propertyDb.transaction();
    try {
      const outlet_id = req.user.outlet_id;
      const { challan_id, otp, remark, receiver_name } = req.body;
      if (!challan_id) {
        await t.rollback();
        return res.status(400).json({ success: false, message: "Challan ID is required." });
      }
      const challan = await req.propertyDb.models.delivery_challan_headers.findOne({
        where: { id: challan_id, outlet_id },
        transaction: t
      });
      if (!challan) {
        await t.rollback();
        return res.status(404).json({ success: false, message: "Delivery challan not found." });
      }
      if (challan.delivery_status === "DELIVERED") {
        await t.rollback();
        return res.json({ success: true, message: "This challan is already marked as DELIVERED.", data: challan });
      }
      if (otp && otp.trim() !== "") {
        const cleanInput = otp.toString().trim();
        const storedOtp = (challan.delivery_otp || "").toString().trim();
        if (storedOtp && cleanInput !== storedOtp) {
          await t.rollback();
          return res.status(400).json({ success: false, message: "Invalid Delivery OTP entered. Please verify with recipient." });
        }
      }
      const deliveryNote = remark ? `${remark}${receiver_name ? ` (Received by: ${receiver_name})` : ""}` : receiver_name ? `Received by: ${receiver_name}` : "Goods delivered and verified by driver";
      await challan.update(
        {
          delivery_status: "DELIVERED",
          status: "Delivered",
          delivered_at: /* @__PURE__ */ new Date(),
          delivered_by_remark: deliveryNote
        },
        { transaction: t }
      );
      let tripCompleted = false;
      if (challan.trip_id) {
        const remainingInTrip = await req.propertyDb.models.delivery_challan_headers.count({
          where: {
            outlet_id,
            trip_id: challan.trip_id,
            delivery_status: { [import_sequelize.Op.ne]: "DELIVERED" }
          },
          transaction: t
        });
        if (remainingInTrip === 0) {
          tripCompleted = true;
          if (challan.vehicle_id) {
            await req.propertyDb.models.transport_vehicles.update(
              {
                status: "AVAILABLE",
                current_trip_id: null,
                current_driver_id: null
              },
              { where: { id: challan.vehicle_id, outlet_id }, transaction: t }
            );
          }
          if (challan.driver_id) {
            await req.propertyDb.models.transport_drivers.update(
              {
                status: "AVAILABLE",
                current_vehicle_id: null
              },
              { where: { id: challan.driver_id, outlet_id }, transaction: t }
            );
          }
        }
      } else if (challan.vehicle_id) {
        const remainingOnVehicle = await req.propertyDb.models.delivery_challan_headers.count({
          where: {
            outlet_id,
            vehicle_id: challan.vehicle_id,
            delivery_status: { [import_sequelize.Op.ne]: "DELIVERED" }
          },
          transaction: t
        });
        if (remainingOnVehicle === 0) {
          tripCompleted = true;
          await req.propertyDb.models.transport_vehicles.update(
            { status: "AVAILABLE", current_trip_id: null, current_driver_id: null },
            { where: { id: challan.vehicle_id, outlet_id }, transaction: t }
          );
          if (challan.driver_id) {
            await req.propertyDb.models.transport_drivers.update(
              { status: "AVAILABLE", current_vehicle_id: null },
              { where: { id: challan.driver_id, outlet_id }, transaction: t }
            );
          }
        }
      }
      await t.commit();
      return res.json({
        success: true,
        message: tripCompleted ? `Challan ${challan.challan_no} delivered! All deliveries complete; Truck & Driver are now AVAILABLE.` : `Challan ${challan.challan_no} marked as DELIVERED!`,
        data: {
          challan,
          tripCompleted
        }
      });
    } catch (err) {
      await t.rollback();
      console.error("verifyDelivery error:", err);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
  // =========================================================================
  // RELEASE VEHICLE & DRIVER TRIP MANUALLY
  // =========================================================================
  static async releaseTrip(req, res) {
    const t = await req.propertyDb.transaction();
    try {
      const outlet_id = req.user.outlet_id;
      const { vehicle_id, driver_id, trip_id } = req.body;
      if (vehicle_id) {
        await req.propertyDb.models.transport_vehicles.update(
          { status: "AVAILABLE", current_trip_id: null, current_driver_id: null },
          { where: { id: vehicle_id, outlet_id }, transaction: t }
        );
      }
      if (driver_id) {
        await req.propertyDb.models.transport_drivers.update(
          { status: "AVAILABLE", current_vehicle_id: null },
          { where: { id: driver_id, outlet_id }, transaction: t }
        );
      }
      if (trip_id) {
        await req.propertyDb.models.transport_vehicles.update(
          { status: "AVAILABLE", current_trip_id: null, current_driver_id: null },
          { where: { current_trip_id: trip_id, outlet_id }, transaction: t }
        );
      }
      await t.commit();
      return res.json({ success: true, message: "Vehicle and Driver have been marked AVAILABLE." });
    } catch (err) {
      await t.rollback();
      console.error("releaseTrip error:", err);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
  // =========================================================================
  // ACTIVE TRIPS & DISPATCH MANIFEST
  // =========================================================================
  static async getActiveTrips(req, res) {
    try {
      const outlet_id = req.user.outlet_id;
      const bookedVehicles = await req.propertyDb.models.transport_vehicles.findAll({
        where: {
          outlet_id,
          status: { [import_sequelize.Op.in]: ["BOOKED", "IN_TRANSIT"] },
          is_active: true
        },
        include: [
          {
            model: req.propertyDb.models.transport_drivers,
            as: "current_driver",
            required: false
          }
        ]
      });
      const activeTrips = [];
      for (const vehicle of bookedVehicles) {
        const plainVehicle = vehicle.toJSON();
        const tripWhere = {
          outlet_id,
          vehicle_id: plainVehicle.id,
          delivery_status: { [import_sequelize.Op.ne]: "DELIVERED" }
        };
        const challans = await req.propertyDb.models.delivery_challan_headers.findAll({
          where: tripWhere,
          include: [
            {
              model: req.propertyDb.models.delivery_challan_items,
              as: "items"
            }
          ]
        });
        activeTrips.push({
          vehicle: plainVehicle,
          driver: plainVehicle.current_driver,
          trip_id: plainVehicle.current_trip_id,
          challan_count: challans.length,
          challans
        });
      }
      return res.json({ success: true, data: activeTrips });
    } catch (err) {
      console.error("getActiveTrips error:", err);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
}
var transport_controller_default = TransportController;
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {
  TransportController
});
