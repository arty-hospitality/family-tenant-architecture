# Family-Tenant Architecture™

**Family-Tenant Architecture™** คือแนวคิดการออกแบบระบบ multi-tenant แบบใหม่  
ที่ต่อยอดจากโมเดลเดิม ให้รองรับ **หลายสาขาภายใต้ tenant เดียว**  
โดยใช้การเปรียบเทียบกับ “ครอบครัว” เพื่อให้เข้าใจง่ายและจัดการได้เป็นระบบ

---

## แนวคิดหลัก
- **Tenant = ครอบครัว** → องค์กร/โรงแรมหนึ่งแห่ง  
- **Property = ลูก** → แต่ละสาขาขององค์กร  
- **User = สมาชิกครอบครัว** → บทบาทต่าง ๆ เช่น Owner, Admin, Supervisor, Staff  
- **House Rules = Tenant Policy** → กฎกลางของบ้าน ลูกทุกคนต้องปฏิบัติตาม เว้นแต่บางข้อที่ override ได้  
- **นามสกุลพ่อ = tenant_id** → ระบุที่ข้อมูลทุกชิ้น ป้องกัน “หลงบ้าน”  
- **หย่า & แต่งใหม่** → archive property เก่า หรือ spin-off tenant ใหม่

---

## ต่างจาก Multi-Tenant แบบดั้งเดิม
| แบบดั้งเดิม (Multi-Tenant)        | Family-Tenant Architecture™            |
|------------------------------------|----------------------------------------|
| 1 tenant = 1 องค์กร จบ             | 1 tenant = 1 องค์กร + หลายสาขา        |
| เปิดสาขาใหม่ = สร้าง tenant ใหม่    | เปิดสาขาใหม่ = เพิ่ม property ใต้ tenant เดิม |
| User ซ้ำในหลาย tenant              | User เดียว map ไปหลาย property        |
| Query cross-tenant ซับซ้อน         | Query cross-property ง่าย (tenant_id > property_id) |

---

## ประโยชน์
- ลด duplication (user, rules, inventory ใช้ร่วมกันได้)  
- Query/report ง่ายขึ้นด้วย key hierarchy (`tenant_id > property_id > record`)  
- Security & data integrity ชัดเจน (RLS + ACL)  
- Scale สะดวก ไม่ต้องแตก tenant ย่อยพร่ำเพรื่อ  
- เหมาะกับธุรกิจแบบ “หลายสาขา หนึ่งองค์กร”

---

© 2025 ArtyHospitality. All rights reserved.  
*Family-Tenant Architecture™ is a trademark of Arty Hospitality.*
