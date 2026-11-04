"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
const taxGroupCtrl = require('../controllers/settings/taxGroup.controller');
router.get('/', taxGroupCtrl.getTaxGroups);
router.post('/seed-defaults', taxGroupCtrl.seedDefaultTaxGroups);
router.post('/reset-defaults', taxGroupCtrl.seedDefaultTaxGroups);
router.post('/', taxGroupCtrl.createTaxGroup);
router.put('/:id', taxGroupCtrl.updateTaxGroup);
router.delete('/:id', taxGroupCtrl.deleteTaxGroup);
module.exports = router;
exports.default = router;
